# Functional qualification only. The two preparation workers bound concurrency;
# no model calls or performance measurements are made.
{:ok, _} = Registry.start_link(keys: :duplicate, name: Eab.Commands)
{:ok, _} = Task.Supervisor.start_link(name: Eab.Tasks)
{:ok, _} = Application.ensure_all_started(:req)

report =
  Eab.Qualification.run(&IO.puts/1,
    id: "qualification-task-quality-v3",
    lookahead: 2,
    preparation_workers: 2
  )

IO.puts("PROMOTION QUALIFICATION #{report["status"]}: #{report["release"]}")
unless report["status"] == "qualified", do: System.halt(1)
