defmodule Eventize.EventSourcedProcess.InitPipeline do
  @moduledoc false
  use Eventize.ExecutionPipelines.Pipeline,
    context: Eventize.EventSourcedProcess.InitPipeline.ExecutionContext,
    function_name: :init

  defmodule ExecutionContext do
    @moduledoc false

    @type t :: %__MODULE__{
            input: term(),
            build_response: (Eventize.EventSourcedProcessState.t() -> term()),
            state: Eventize.EventSourcedProcessState.t(),
            step_data: map(),
            process: atom()
          }

    defstruct [:input, :state, :process, :build_response, step_data: %{}]
  end
end
