defmodule Eventize.EventSourcedProcess.InitPipeline do
  @moduledoc """
  The `Eventize.ExecutionPipeline` used to initialize a
  `Eventize.EventSourcedProcess`.
  """

  use Eventize.ExecutionPipeline,
    context: Eventize.EventSourcedProcess.InitPipeline.ExecutionContext,
    function_name: :init

  defmodule ExecutionContext do
    @moduledoc """
    The context used to initialize a `Eventize.EventSourcedProcess`.
    """

    @type t :: %__MODULE__{
            input: term(),
            build_response: (Eventize.EventSourcedProcessState.t() -> term()),
            state: Eventize.EventSourcedProcessState.t(),
            step_data: map(),
            process: atom()
          }

    @enforce_keys [:input, :state, :process, :build_response]

    defstruct [:input, :state, :process, :build_response, step_data: %{}]
  end
end
