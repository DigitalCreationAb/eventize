defmodule TestEntityWithBehavior do
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
    
    defmodule SecondTitleUpdated do
      defstruct secondTitle: nil
    end
  end

  defmodule Responses do
    defmodule StartResponse do
      defstruct title: nil
    end
  end
  
  defmodule NotStarted do
    def execute(%Reactive.Entities.Entity.ExecutionContext{}, %Commands.Start{:title => title}) do
      {[%Events.Started{title: title}], %Responses.StartResponse{title: title}}
    end
  end
  
  defmodule Started do
    def execute(%Reactive.Entities.Entity.ExecutionContext{}, %Commands.Start{:title => title}) do
      {[%Events.SecondTitleUpdated{secondTitle: title}], %Responses.StartResponse{title: title}}
    end
  end

  @impl true
  def start(_id) do
    NotStarted
  end

  defp on(state, %Events.Started{:title => title}) do
    {Map.put(state, :title, title), Started}
  end
  
  defp on(state, %Events.SecondTitleUpdated{:secondTitle => title}) do
    Map.put(state, :secondTitle, title)
  end
end