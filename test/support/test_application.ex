defmodule TestApplication do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      TestEntitiesSupervisor,
      {Reactive.Persistence.InMemoryEventStore, name: Reactive.Persistence.InMemoryEventStore}
    ]
    
    opts = [strategy: :one_for_one, name: TestApplication.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
