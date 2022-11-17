defmodule TestPersistedEntityWithoutBehavior do
  use Reactive.Entities.PersistedEntity

  defmodule Commands do
    defmodule Start do
      defstruct title: nil
    end
    
    defmodule GetTitle do
      defstruct id: nil
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
    
    defmodule GetTitleResponse do
      defstruct title: nil
    end
  end

  def execute(%Reactive.Entities.Entity.ExecutionContext{}, %Commands.Start{:title => title}) do
    {[%Events.Started{title: title}], %Responses.StartResponse{title: title}}
  end
  
  def execute(%Reactive.Entities.Entity.ExecutionContext{:state => state}, %Commands.GetTitle{}) do
    %Responses.GetTitleResponse{title: state.title}
  end

  defp on(state, %Events.Started{:title => title}) do
    Map.put(state, :title, title)
  end
end
