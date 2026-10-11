# Historical Plausible CE runtime research

Investigated 2026-10-11 for wiring the six [historical candidates](plausible-pr-candidates.md) into the benchmark. This is static source evidence, not runtime qualification. Inspection used `git show`, `git diff` and source searches in `.local/plausible-authoring`; the checkout was not changed. No builds, tests or measurements ran.

## Runtime groups and unchanged environment inputs

All six repair-parent comparisons leave `.tool-versions`, `config/`, `.github/workflows/elixir.yml`, `mix.exs`, `mix.lock` and `tracker/` unchanged. Each historical pair can therefore use the same environment inputs on its broken and repaired sides. That does not establish compatibility between different pairs.

| PRs | Erlang | Elixir | Node | CE PostgreSQL | ClickHouse |
| --- | --- | --- | --- | --- | --- |
| #5939, #5956 | 27.3.4.6 | 1.19.4-otp-27 | 23.2.0 | `postgres:16` | `clickhouse/clickhouse-server:24.12.2.29-alpine` |
| #6300, #6449 | 27.3.4.6 | 1.19.4-otp-27 | 23.2.0 | `postgres:18` | `clickhouse/clickhouse-server:25.11.5.8-alpine` |
| #6441, #6763 | 28.5.0.5 | 1.20.4-otp-28 | 24.17.0 | `postgres:18` | `clickhouse/clickhouse-server:25.11.5.8-alpine` |

Sources: [#5939 toolchain](https://github.com/plausible/analytics/blob/c4ea07d8bc38deacb7c6291ff073bcf814f113f8/.tool-versions), [#5939 CI](https://github.com/plausible/analytics/blob/c4ea07d8bc38deacb7c6291ff073bcf814f113f8/.github/workflows/elixir.yml), [#5956 CI](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/.github/workflows/elixir.yml), [#6300 toolchain](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/.tool-versions), [#6300 CI](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/.github/workflows/elixir.yml), [#6449 CI](https://github.com/plausible/analytics/blob/63929d339231e107c5eda8b4499250ea16246a6d/.github/workflows/elixir.yml), [#6441 toolchain](https://github.com/plausible/analytics/blob/37e352c73dc586314a43985a81371df895ed6c14/.tool-versions), [#6441 CI](https://github.com/plausible/analytics/blob/37e352c73dc586314a43985a81371df895ed6c14/.github/workflows/elixir.yml), [#6763 CI](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/.github/workflows/elixir.yml).

The newer ClickHouse CI sets `CLICKHOUSE_SKIP_USER_SETUP=1`. Both CI generations use PostgreSQL password `postgres`, port 5432, and ClickHouse HTTP port 8123. The older matrix has PG15 for EE but explicitly PG16 for CE; using the first matrix entry without checking the edition would select the wrong historical CE service. The upstream tags above are starting inputs; record image digests for the final reproducible recipe. [Older CE matrix](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/.github/workflows/elixir.yml), [newer services](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/.github/workflows/elixir.yml).

## Build and database setup

Set `MIX_ENV=ce_test` for the entire build, including the tracker JavaScript step. This environment compiles `lib` and `test/support`; ordinary `test` additionally compiles `extra/lib`. The tracker compiler also reads `MIX_ENV` to omit variants marked enterprise-only. `config/ce_test.exs` imports `test.exs`, and runtime configuration loads `config/.env.test` for CE tests. [Mix paths](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/mix.exs), [tracker variant selection](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/tracker/compiler/index.js), [CE config](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/config/ce_test.exs), [runtime config](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/config/runtime.exs).

The ordinary upstream Elixir CI prepares assets and dependencies in this order. These are commands for the future isolated correctness environment, not commands executed during this investigation:

```bash
export MIX_ENV=ce_test
npm install --prefix ./tracker
npm run deploy --prefix ./tracker
mix deps.get --only ce_test
mix compile --warnings-as-errors --all-warnings
mix do ecto.create, ecto.migrate
```

All six snapshots contain `tracker/package-lock.json`. Upstream uses `npm install`; a harness change to `npm ci` should be qualified against that historical lockfile rather than assumed to work. The ordinary Elixir CI builds the tracker, not the dashboard assets or browser environment. Do not add `mix assets.deploy`, Playwright installation or e2e setup merely to run these backend and LiveView tests. [Older CI build sequence](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/.github/workflows/elixir.yml), [newer CI build sequence](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/.github/workflows/elixir.yml).

Tracker assets must exist before Elixir compilation. `PlausibleWeb.Tracker` reads `priv/tracker/js/plausible-web.js` into a module attribute and touches a missing file for static-check convenience. A successful compile can therefore embed an empty script. Validate the real generated asset and delivered script contents; recompilation is needed if the asset changes afterward. CI also checks `priv/tracker/installation_support/verifier.js`. [Tracker compile-time read](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/lib/plausible_web/tracker.ex), [tracker tests' asset prerequisite](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/test/plausible_web/plugs/tracker_plug_test.exs).

All six configure `ecto_repos: [Plausible.Repo, Plausible.IngestRepo]`. Consequently the create/migrate commands prepare both PostgreSQL and ClickHouse. The application starts the analytics repositories even for the date and LiveView cases. The common test alias is:

```elixir
test: ["ecto.create --quiet", "ecto.migrate", "test", "clean_clickhouse"]
```

`ecto.setup` also runs `priv/repo/seeds.exs`; it is not the CI preparation command. `clean_clickhouse` truncates application tables while retaining migration and dictionary tables. Use isolated case databases/services: the task is not limited to transaction rollback in PostgreSQL. No source-level database suffix using `MIX_TEST_PARTITION` was found in the inspected configuration, repository modules or test support; CI partition numbers select tests, and separate jobs supply isolation. [Repository configuration](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/config/config.exs), [application repositories](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/lib/plausible/application.ex), [aliases](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/mix.exs), [ClickHouse cleanup](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/lib/mix/tasks/clean_clickhouse.ex).

The checked-in test environment supplies local database URLs, test-only secrets, endpoint URL, fake service credentials and the checked-in geolocation fixture. Preserve its non-database behavior when adapting addresses for containers. Upstream additionally invokes `Tzdata.ReleaseUpdater.poll_for_update`; the harness should capture the resulting timezone data during image construction and freeze it for attempts, especially #6300. This is a reproducibility recommendation, not a claim that offline startup has been verified. [Historical test environment](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/config/.env.test), [newer test environment](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/config/.env.test), [timezone preparation](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/.github/workflows/elixir.yml).

## Test selection and bounded regression commands

CE excludes `ee_only`, `slow`, `minio` and `migrations` by default in #5939/#5956. The other four snapshots additionally exclude `e2e`. Enterprise mode instead excludes `ce_build_only`, so selecting a CE-only cache file under default `MIX_ENV=test` can produce a misleading empty run. None of the relevant added tests for the first five candidates needs `slow`, MinIO, migration-test inclusion or browser tags. #5939 has unrelated EE cases in the same file; CE exclusions should remain active. [Older helper](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/test/test_helper.exs), [middle helper](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/test/test_helper.exs), [newer helper](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/test/test_helper.exs).

Use explicit files for bounded correctness runs, with this common command shape:

```bash
MIX_ENV=ce_test mix test PATH --seed 0 --max-failures 1
```

| PR | Upstream regression file | Qualification detail |
| --- | --- | --- |
| #6300 | `test/plausible/stats/comparisons_test.exs` | Fixed `now` inputs; retain UTC and US/Eastern cases and option-off control. |
| #5939 | `test/plausible_web/live/change_domain_test.exs` | Added role matrix requires `add_site_guest_or_team_member/2` from the repaired test support, or equivalent grader-local setup. Keep CE exclusions. |
| #6763 | `test/plausible_web/controllers/api/stats_controller/dashboard_csv_export_test.exs` | Real native analytics rows and zip/CSV response checks; no MinIO tag. |
| #6449 | `test/plausible_web/live/shared_link_settings/form_test.exs` | Real LiveView and PostgreSQL assertions; same-site personal segment is a positive control. |
| #6441 | `test/plausible_web/controllers/api/external_stats_controller/query_goal_custom_props_test.exs` | Native/imported rows and real Stats API; retain ordinary imported-goal controls. |
| #5956 | Grader-owned focused cache/delivery file; upstream `test/plausible_web/plugs/tracker_plug_test.exs` for surrounding delivery regressions | New cache module in the upstream added file does not exist on the parent. Use the shared public APIs below. |

Pinned files: [#6300](https://github.com/plausible/analytics/blob/dcb92e5cc5493f4d778df726371336d376e799a2/test/plausible/stats/comparisons_test.exs), [#5939](https://github.com/plausible/analytics/blob/c4ea07d8bc38deacb7c6291ff073bcf814f113f8/test/plausible_web/live/change_domain_test.exs), [#6763](https://github.com/plausible/analytics/blob/bc2c7b395caddf7bb4eec2548be7958824d07d4a/test/plausible_web/controllers/api/stats_controller/dashboard_csv_export_test.exs), [#6449](https://github.com/plausible/analytics/blob/63929d339231e107c5eda8b4499250ea16246a6d/test/plausible_web/live/shared_link_settings/form_test.exs), [#6441](https://github.com/plausible/analytics/blob/37e352c73dc586314a43985a81371df895ed6c14/test/plausible_web/controllers/api/external_stats_controller/query_goal_custom_props_test.exs), [#5956 delivery](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/test/plausible_web/plugs/tracker_plug_test.exs).

The parent needs the acceptance additions overlaid separately; merely running its original file does not add missing coverage. Check executed test identities/counts and distinguish expected behavior failures from missing helpers, compilation failures and excluded tests. Do not run the broad `tracker_test.exs` file as this case's focused oracle: it also contains database-query-count assertions unrelated to the desired delivery contract. [Tracker test contents](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/test/plausible_web/tracker_test.exs).

## #5956: one acceptance path for both historical states

The broken parent is `10b116974d486603819e78668e99fa49a3162c5a`; the repair is `121ef8de14f0d4fec0c78c465833c4b8351655e7`. Both expose these `PlausibleWeb.Tracker` functions with the same roles and signatures:

```elixir
get_or_create_tracker_script_configuration!(site, params)
update_script_configuration!(site, params, :installation)
get_tracker_script_configuration_by_id(id)
get_tracker_script_configuration_base_query()
build_script(configuration)
get_plausible_main_script(id, cache_options)
```

Both serve the configured script at `GET /js/#{configuration.id}.js`; configuration IDs already carry the `pa-` prefix. The plug accepts a binary script or nil. A cache value containing multiple script versions reaches neither branch and causes the reported error. [Parent Tracker](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible_web/tracker.ex), [repaired Tracker](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/lib/plausible_web/tracker.ex), [delivery plug](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible_web/plugs/tracker_plug.ex).

Two source-level pitfalls would conceal the historical defect:

- `config/test.exs` sets `Plausible.Cache, enabled: false`. Ordinary reads then call `get_from_source`, bypassing the production cache. Pass `force?: true` for direct Tracker reads; enable cache access in a serialized test for the actual HTTP path, then restore the previous configuration.
- The parent application starts `:tracker_script_cache` with `ets_options: [:bag, read_concurrency: true]`. The repaired application drops `:bag`. Starting a separate test cache with default options would replace the parent's faulty production setup with a set and mask the problem.

Sources: [cache-disabled config](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/config/test.exs), [fallback and force option](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible/cache.ex), [parent supervision](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible/application.ex), [repaired supervision](https://github.com/plausible/analytics/blob/121ef8de14f0d4fec0c78c465833c4b8351655e7/lib/plausible/application.ex).

The parent broadcasts cache writes asynchronously; the repair performs a synchronous CE put. Avoid sleep-based observation of that race. A deterministic compatibility fixture can use the common public configuration query and script builder, then the common cache adapter's synchronous bulk insertion. This is the insertion operation used by the real refresh path, against the application-started cache:

```elixir
defp refresh_tracker_contents do
  entries =
    PlausibleWeb.Tracker.get_tracker_script_configuration_base_query()
    |> Plausible.Repo.all()
    |> Enum.map(fn config ->
      {config.id, PlausibleWeb.Tracker.build_script(config)}
    end)

  :ok = Plausible.Cache.Adapter.put_many(:tracker_script_cache, entries)
end
```

This compatibility helper exercises the refresh insertion path without naming either the removed `PlausibleWeb.TrackerScriptCache` module or the repaired-only `Plausible.Site.TrackerScriptCache`. It omits full-refresh stale-key cleanup; that is outside this configuration-update scenario and should not be represented as full cache-refresh coverage. [Parent refresh/merge implementation](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible/cache.ex), [common bulk insertion](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible/cache/adapter.ex), [parent cache contents](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/lib/plausible_web/tracker_script_cache.ex).

Suggested deterministic scenario, still requiring execution qualification:

1. Use `PlausibleWeb.ConnCase, async: false`, preserving the normal application's cache child. Create two sites through existing fixtures.
2. Create manual tracker configurations through `Tracker.get_or_create_tracker_script_configuration!/2`, with `file_downloads: false`; synchronously insert the current generated contents using the helper.
3. Confirm the first delivered script is a binary with its own domain and a real tracker body. Do not accept only equality with `build_script/1`, because that could allow an empty asset to satisfy the check.
4. Call `Tracker.update_script_configuration!(site, %{file_downloads: true}, :installation)`, then synchronously refresh the current contents again. The parent bag can now contain old and new versions for one ID; the repaired set retains the current version.
5. With cache access enabled only for the serialized HTTP assertions, request `/js/#{config.id}.js`. Require status 200, the correct domain, and `fileDownloads:!0`. Check that the other site's script retains its independent settings.
6. Change the flag back to false, refresh, and verify the marker disappears while delivery still succeeds. Retain an unknown-ID 404 control. Restore the previous cache-enabled configuration on exit; remove test-created cache entries using the common adapter if needed for isolation.

`ConnCase` checks out PostgreSQL sandbox ownership and uses shared mode when the test is not async. The normal endpoint does not need a listening HTTP server for `Phoenix.ConnTest.get/2`. The proposed fixture invokes real configuration, generation, cache and delivery code; it does not assert a particular repaired module name or class of ETS table. Runtime acceptance must still demonstrate the intended failure on the parent and success on the repair. [ConnCase setup](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/test/support/conn_case.ex), [existing script delivery assertions](https://github.com/plausible/analytics/blob/10b116974d486603819e78668e99fa49a3162c5a/test/plausible_web/plugs/tracker_plug_test.exs).
