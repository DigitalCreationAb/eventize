defmodule Eventize.EventSourcedProcess.ExecutionPipeline do
  @moduledoc """
  The `Eventize.ExecutionPipeline` used to execute incoming
  messages to a process.
  """

  use Eventize.ExecutionPipeline,
    context: Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext

  defmodule ExecutionContext do
    @moduledoc """
    The context used to execute a incoming message to a process.
    """

    @type t :: %__MODULE__{
            input: term(),
            build_response: (Eventize.EventSourcedProcessState.t() -> term()),
            state: Eventize.EventSourcedProcessState.t(),
            step_data: map(),
            type: :cast | :call,
            from: pid() | nil
          }

    @enforce_keys [:input, :build_response, :state, :type]

    defstruct [:input, :build_response, :state, :type, step_data: %{}, from: nil]
  end
end
