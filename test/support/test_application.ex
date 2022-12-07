defmodule TestApplication do
  @moduledoc false

  use Application

  def start(_type, _args) do
    TestEntitiesSupervisor.start_link()

    Reactive.Persistence.InMemoryEventStore.start_link([],
      name: Reactive.Persistence.InMemoryEventStore
    )
  end
end
