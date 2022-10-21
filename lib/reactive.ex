defmodule Reactive do
  @moduledoc """
  Defines a Reactive application.
  """
  
  use Application

  def start(_type, _args) do
    Reactive.Entities.Supervisor.start_link()
    Reactive.Persistence.EventStore.start_link()
  end
  
  @doc """
  Sends a commands to a `Reactive.Entities.Entity`.
  """
  def send(entity, id, command) when is_atom(entity) and is_struct(command) do
    pid = Reactive.Entities.Supervisor.get_entity(entity, id)

    GenServer.cast(pid, {:execute, command})
  end
  
  @doc """
  Sends a commands to a `Reactive.Entities.Entity` 
  and returns the response from that entity.
  """
  def ask(entity, id, command) when is_atom(entity) and is_struct(command) do
    pid = Reactive.Entities.Supervisor.get_entity(entity, id)

    GenServer.call(pid, {:execute, command})
  end
end
