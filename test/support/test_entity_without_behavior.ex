defmodule TestEntityWithoutBehavior do
  use Reactive.Entities.Entity

  defmodule Commands do
    defmodule Start do
      defstruct title: nil
    end
  end

  defmodule Events do
    defmodule Started do
      defstruct title: nil
    end
  end

  defmodule Responses do
    defmodule StartResponse do
      defstruct title: nil
    end
  end

  def execute(%Reactive.Entities.Entity.ExecutionContext{}, %Commands.Start{:title => title}) do
    {[%Events.Started{title: title}], %Responses.StartResponse{title: title}}
  end
  
  defp on(state, %Events.Started{:title => title}) do
    Map.put(state, :title, title)
  end
end