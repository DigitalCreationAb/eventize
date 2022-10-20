defmodule TestEntityWithoutBehavior do
  use Reactive.Entities.Entity

  defmodule Commands do
    defmodule Start do
      defstruct title: nil
    end
    
    defmodule Stop do
      defstruct id: nil
    end
  end

  defmodule Events do
    defmodule Started do
      defstruct title: nil
    end
    
    defmodule Stopped do
      defstruct id: nil
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
  
  def execute(%Reactive.Entities.Entity.ExecutionContext{:id => id}, %Commands.Stop{}) do
    [%Events.Stopped{id: id}]
  end
  
  defp on(state, %Events.Started{:title => title}) do
    Map.put(state, :title, title)
  end
  
  defp get_lifespan(%Events.Stopped{}, _state) do
    :stop
  end
end