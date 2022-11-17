defmodule TestCommandBus do
  @moduledoc false

  @behaviour Reactive.Entities.CommandBus
  
  def call(entity_type, id, command) do
    pid = TestEntitiesSupervisor.get_entity(entity_type, id)

    GenServer.call(pid, {:execute, command})
  end
  
  def cast(entity_type, id, command) do
    pid = TestEntitiesSupervisor.get_entity(entity_type, id)

    GenServer.cast(pid, {:execute, command})
  end
end
