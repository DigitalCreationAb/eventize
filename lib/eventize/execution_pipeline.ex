defmodule Eventize.ExecutionPipeline do
  @moduledoc """
  This module can be used to create a pipeline of
  functions that should be executed in a certain order.
  Each function is responsible for executing the next
  function in the pipeline.
  """

  defmodule DefaultContext do
    @moduledoc """
    A default, empty, context used in a `Eventize.ExecutionPipeline`
    that doesn't specify a context.
    """

    @type t :: %__MODULE__{}

    defstruct []
  end

  defmacro __using__(options) do
    context = Keyword.get(options, :context, Eventize.ExecutionPipelines.Pipeline.DefaultContext)
    function_name = Keyword.get(options, :function_name, :execute)
    module = __CALLER__.module

    quote do
      @type execution_pipeline :: (unquote(context).t() -> unquote(context).t())

      defmodule PipelineStep do
        @moduledoc """
        A behaviour that specifies how a step should execute.
        """

        @type pipeline_step :: (unquote(context).t(), pipeline_step() -> unquote(context).t())

        @callback unquote(function_name)(
                    unquote(context).t(),
                    unquote(module).execution_pipeline()
                  ) ::
                    unquote(context).t()
      end

      @spec build_pipeline(list(PipelineStep.pipeline_step() | atom())) ::
              list(execution_pipeline())
      def build_pipeline(steps) when is_list(steps) do
        last_step = fn context -> context end

        steps
        |> Enum.reverse()
        |> Enum.reduce(last_step, &get_step/2)
      end

      defp get_step(step, current) do
        case {step, is_pipeline_step(step)} do
          {s, true} ->
            fn context -> s.unquote(function_name)(context, current) end

          {f, _} when is_function(f, 2) ->
            fn context -> f.(context, current) end

          _ ->
            current
        end
      end

      defp is_pipeline_step(module) when is_atom(module) do
        all = Keyword.take(module.__info__(:attributes), [:behaviour])

        [PipelineStep] in Keyword.values(all)
      end

      defp is_pipeline_step(_module) do
        false
      end
    end
  end
end
