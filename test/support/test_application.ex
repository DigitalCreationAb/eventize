defmodule TestApplication do
  @moduledoc false

  use Application

  def start(_type, _args) do
    TestEntitiesSupervisor.start_link()
    Reactive.Persistence.EventStore.start_link()
  end
end
