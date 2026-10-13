defmodule Eab.Source do
  @moduledoc "Pristine source snapshots cached by repository and exact revision."
  alias Eab.{Command, Inventory, Store}

  def snapshot(repo, source, emit) do
    key = Inventory.hash(Jason.encode!([repo["url"], repo["revision"]]))
    archive = Store.path("sources/#{key}.tar")

    if File.regular?(archive) do
      emit.("Reusing source snapshot at #{repo["revision"]}")
      Command.run!("tar", ["-xf", archive, "-C", source])
    else
      Command.run!("git", ["init", "--quiet", source])

      Command.run!("git", ["fetch", "--quiet", "--depth=1", repo["url"], repo["revision"]],
        cd: source
      )

      Command.run!("git", ["checkout", "--quiet", "--detach", "FETCH_HEAD"], cd: source)

      unless String.trim(Command.run!("git", ["rev-parse", "HEAD"], cd: source)) ==
               repo["revision"],
             do: raise("Fetched source revision does not match the case")

      File.mkdir_p!(Path.dirname(archive))
      File.chmod!(Path.dirname(archive), 0o700)
      temp = archive <> ".#{System.unique_integer([:positive])}.tmp"

      try do
        File.rm_rf!(Path.join(source, ".git"))
        Command.run!("tar", ["-cf", temp, "-C", source, "."])
        File.chmod!(temp, 0o600)
        File.rename!(temp, archive)
      after
        File.rm(temp)
      end
    end
  end
end
