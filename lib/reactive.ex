defmodule Reactive do
  use Application

  def start(_type, _args) do
    Reactive.Entities.Supervisor.start_link()
    Reactive.Persistence.EventStore.start_link()
  end
  
  def send(entity, id, command) when is_atom(entity) and is_struct(command) do
    pid = Reactive.Entities.Supervisor.get_entity(entity, id)

    GenServer.cast(pid, {:execute, command})
  end
  
  def ask(entity, id, command) when is_atom(entity) and is_struct(command) do
    pid = Reactive.Entities.Supervisor.get_entity(entity, id)

    GenServer.call(pid, {:execute, command})
  end
end
