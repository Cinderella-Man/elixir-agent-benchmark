defmodule Eab.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: Eab.PubSub},
      {Registry, keys: :duplicate, name: Eab.Commands},
      {Task.Supervisor, name: Eab.Tasks},
      Eab.Runs,
      EabWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_all, name: Eab.Supervisor)
  end
end
