defmodule Eab.FixturesTest do
  use ExUnit.Case, async: false

  alias Eab.{
    AgentImage,
    Baseline,
    BuildCache,
    Cache,
    Command,
    Fixtures,
    Grader,
    Inventory,
    Source,
    Store
  }

  setup do
    old = Application.fetch_env!(:eab, :data_dir)
    root = Path.join(System.tmp_dir!(), "eab-cache-test-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, old)
      File.rm_rf!(root)
    end)

    %{root: root}
  end

  test "matching image records reuse prepared dependencies and refresh fixture evidence" do
    id = "plausible-pr-6300"
    inputs = Fixtures.build_inputs(id, Inventory.spec(id))

    runtime = %{
      "inputs" => inputs,
      "image" => "fixture",
      "images" => ["fixture"],
      "fixture_hashes" => %{}
    }

    opts = [image_exists?: fn _ -> true end]
    Cache.fetch("projects", inputs, fn _ -> runtime end, opts)
    services = %{"postgres" => "engine"}
    engine_inputs = %{"services" => Inventory.spec(id)["services"]}

    Cache.fetch(
      "engines",
      engine_inputs,
      fn _ -> %{"services" => services, "images" => ["engine"]} end,
      opts
    )

    database_inputs =
      Baseline.inputs(Map.put(runtime, "services", services), Baseline.policy(Inventory.spec(id)))

    Cache.fetch(
      "databases",
      database_inputs,
      fn _ ->
        %{"services" => %{"postgres" => "database"}, "images" => ["database"], "depth" => 1}
      end,
      opts
    )

    parent = self()

    exists? = fn image ->
      send(parent, {:inspected, image})
      true
    end

    result = Fixtures.ensure(id, &send(parent, {:progress, &1}), image_exists?: exists?)
    assert_receive {:inspected, "fixture"}
    assert_receive {:inspected, "database"}
    assert_receive {:progress, "Reusing prepared project for plausible-pr-6300"}
    assert result["fixture_hashes"] == Inventory.fixture_hashes(id)
    assert Store.read("runtimes/#{id}.json") == result
    refute File.exists?(Store.path("build/#{id}"))
  end

  test "matching qualification receipts are reused without running controls" do
    id = "plausible-pr-6300"
    runtime = %{"image" => "synthetic-prepared-image"}

    control = %{
      "valid" => true,
      "identity" => Grader.qualification_identity(id, runtime)
    }

    Store.write("runtimes/#{id}.json", runtime)
    Store.write("qualifications/#{Cache.key(control["identity"])}.json", control)
    parent = self()
    assert Eab.Grader.qualify(id, "cache-test", &send(parent, {:qualification, &1})) == control
    assert_receive {:qualification, "Reusing checked fixture for plausible-pr-6300"}
    refute File.exists?(Store.path("runs/cache-test"))
  end

  test "recipes reconcile seeds before compilation and export an independent fixture" do
    for id <- Inventory.all() do
      spec = Inventory.spec(id)
      recipe = Fixtures.dockerfile(spec, "base", "node")
      {sync, _} = :binary.match(recipe, "Eab.FixtureSeed.sync")
      {deps, _} = :binary.match(recipe, "mix deps.loadpaths")
      {compile, _} = :binary.match(recipe, "RUN mix compile")
      {fixture, _} = :binary.match(recipe, "FROM toolchain AS fixture")
      assert sync < deps and deps < compile and compile < fixture
      refute recipe =~ "/opt/pi"
      assert AgentImage.recipe("project", "node") =~ "COPY --from=pi /opt/pi /opt/pi"
      refute recipe =~ "reference.patch"
      refute recipe =~ "acceptance.patch"
      assert recipe =~ "mix deps.clean --unused"
      assert recipe =~ "sharing=locked"
      refute recipe =~ "mix deps.compile"
      changed = put_in(spec, ["runtime", "setup_commands"], ["mix compile --force"])

      refute Fixtures.build_inputs(id, spec)["recipe_hash"] ==
               Fixtures.build_inputs(id, changed)["recipe_hash"]
    end
  end

  test "project, database and control identities ignore unrelated runtime metadata" do
    id = "plausible-pr-6300"
    spec = Inventory.spec(id)
    changed = spec |> put_in(["services", "postgres", "image"], "new-db")
    assert Fixtures.build_inputs(id, spec) == Fixtures.build_inputs(id, changed)
    changed = put_in(spec, ["runtime", "before_test_commands"], ["reset"])
    assert Fixtures.build_inputs(id, spec) == Fixtures.build_inputs(id, changed)

    runtime = %{
      "image" => "project",
      "services" => %{"postgres" => "baseline"},
      "baseline" => %{"id" => "baseline"}
    }

    identity = Grader.qualification_identity(id, runtime)

    assert Grader.qualification_identity(
             id,
             Map.merge(runtime, %{
               "pi" => "new",
               "build_log" => "other",
               "fixture_hashes" => %{"ticket.md" => "new"}
             })
           ) == identity

    refute Grader.qualification_identity(id, Map.put(runtime, "image", "changed-project")) ==
             identity

    refute Grader.qualification_identity(
             id,
             Map.put(runtime, "services", %{"postgres" => "changed-db"})
           ) == identity
  end

  test "required acceptance checks and unknown future grading rules invalidate controls", %{
    root: root
  } do
    id = "plausible-pr-6300"
    original_root = Inventory.root()
    fixture_root = Path.join(root, "inventory")
    File.mkdir_p!(Path.join(fixture_root, "config"))

    File.cp!(
      Inventory.path("config/benchmark.json"),
      Path.join(fixture_root, "config/benchmark.json")
    )

    File.mkdir_p!(Path.join(fixture_root, "cases"))
    File.cp_r!(Inventory.case_path(id, ""), Path.join(fixture_root, "cases/#{id}"))
    Application.put_env(:eab, :root, fixture_root)
    on_exit(fn -> Application.put_env(:eab, :root, original_root) end)
    spec = Inventory.spec(id)
    original = Inventory.qualification_inputs(id)
    path = Inventory.case_path(id, "case.json")

    for change <- [
          %{"required_acceptance_tests" => ["new check"]},
          %{"future_grading_rule" => true}
        ] do
      File.write!(path, Jason.encode!(Map.merge(spec, change)))
      refute Inventory.qualification_inputs(id) == original
    end

    File.write!(path, Jason.encode!(Map.put(spec, "title", "New description")))
    assert Inventory.qualification_inputs(id) == original
  end

  test "seed compatibility excludes the PR revision but includes installed tools and build policy" do
    spec = Inventory.spec("livebook-pr-2800")
    key = BuildCache.key(spec, "toolchain", "node", "recipe")
    revised = put_in(spec, ["repository", "revision"], "new-revision")
    assert BuildCache.key(revised, "toolchain", "node", "recipe") == key

    for changed <- [
          put_in(spec, ["repository", "url"], "another-repository"),
          put_in(spec, ["runtime", "environment", "MIX_ENV"], "prod"),
          put_in(spec, ["runtime", "setup_commands"], ["mix compile --force"])
        ] do
      refute BuildCache.key(changed, "toolchain", "node", "recipe") == key
    end

    refute BuildCache.key(spec, "updated-native-tools", "node", "recipe") == key
    refute BuildCache.key(spec, "toolchain", "another-node", "recipe") == key
    refute BuildCache.key(spec, "toolchain", "node", "new-recipe") == key

    seed = %{"key" => key, "image" => "pristine-image", "case" => "previous"}
    Store.write("build-seeds/#{key}.json", seed)
    assert BuildCache.find(key, &(&1 == "pristine-image")) == seed
    assert BuildCache.find(key, fn _ -> false end) == nil
    assert BuildCache.find("another-key", fn _ -> flunk("Unexpected inspect") end) == nil

    recipe =
      Fixtures.dockerfile(spec, "base", nil, toolchain: "installed-tools", seed: "seed-image")

    assert recipe =~ "FROM installed-tools AS toolchain"
    assert recipe =~ "COPY --from=seed-image --chown=agent:agent /workspace/ /workspace/"
    refute recipe =~ "apt-get"
  end

  test "source cache preserves exact broken files and excludes later edits and git history", %{
    root: root
  } do
    repo = Path.join(root, "upstream")
    File.mkdir_p!(repo)
    File.write!(Path.join(repo, ".gitattributes"), "ticket.txt export-ignore\n")
    File.write!(Path.join(repo, "ticket.txt"), "original broken source")
    Command.run!("git", ["init", "--quiet", repo])
    Command.run!("git", ["add", "."], cd: repo)

    Command.run!(
      "git",
      ["-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-qm", "original"],
      cd: repo
    )

    revision = Command.run!("git", ["rev-parse", "HEAD"], cd: repo) |> String.trim()
    source1 = Path.join(root, "first")
    source2 = Path.join(root, "second")
    File.mkdir_p!(source1)
    File.mkdir_p!(source2)
    spec = %{"url" => repo, "revision" => revision}
    Source.snapshot(spec, source1, fn _ -> :ok end)
    File.write!(Path.join(source1, "ticket.txt"), "agent modification")
    File.rm_rf!(repo)
    parent = self()
    Source.snapshot(spec, source2, &send(parent, {:cache, &1}))
    assert_receive {:cache, "Reusing source snapshot at " <> ^revision}
    assert File.read!(Path.join(source2, "ticket.txt")) == "original broken source"
    refute File.exists?(Path.join(source1, ".git"))
    refute File.exists?(Path.join(source2, ".git"))
    refute Path.wildcard(Store.path("sources/*.tar")) == []
    assert Path.wildcard(Store.path("sources/*.tmp")) == []
  end
end
