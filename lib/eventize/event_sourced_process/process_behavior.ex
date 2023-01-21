defmodule Eventize.EventSourcedProcess.ProcessBehavior do
  @moduledoc """
  This module describes a process behavior that can execute
  incoming messages to a process. With a process behavior
  you can specify different handlers for different messages
  depending on what has happened to the process before.
  """

  @doc """
  This callback is used in the same way as `c:GenServer.handle_call/3`.
  """
  @callback execute_call(term(), pid(), map()) :: {list(), term()} | list() | term()

  @doc """
  This callback is used in the same way as `c:GenServer.handle_cast/2`.
  """
  @callback execute_cast(term(), map()) :: list() | nil

  @optional_callbacks execute_call: 3,
                      execute_cast: 2
end
