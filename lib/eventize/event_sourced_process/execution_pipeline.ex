defmodule Eventize.EventSourcedProcess.ExecutionPipeline do
  @moduledoc false
  use Eventize.ExecutionPipelines.Pipeline,
    context: Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext

  defmodule ExecutionContext do
    @moduledoc false

    @type t :: %__MODULE__{
            input: term(),
            build_response: (Eventize.EventSourcedProcessState.t() -> term()),
            state: Eventize.EventSourcedProcessState.t(),
            step_data: map(),
            type: :cast | :call,
            from: pid() | nil
          }

    defstruct [:input, :build_response, :state, :type, step_data: %{}, from: nil]
  end
end
