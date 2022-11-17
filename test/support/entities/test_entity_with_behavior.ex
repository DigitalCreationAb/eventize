defmodule TestEntityWithBehavior do
  @moduledoc false
  
  use Reactive.Entities.Entity

  defmodule Commands do
    @moduledoc false
    
    defmodule Start do
      @moduledoc false
      
      defstruct title: nil
    end
  end

  defmodule Events do
    @moduledoc false
    
    defmodule Started do
      @moduledoc false

      defstruct title: nil
    end
    
    defmodule SecondTitleUpdated do
      @moduledoc false
      
      defstruct secondTitle: nil
    end
  end

  defmodule Responses do
    @moduledoc false
    
    defmodule StartResponse do
      @moduledoc false
      
      defstruct title: nil
    end
  end
  
  defmodule NotStarted do
    @moduledoc false
    
    def execute(%Reactive.Entities.Entity.ExecutionContext{}, %Commands.Start{:title => title}) do
      {[%Events.Started{title: title}], %Responses.StartResponse{title: title}}
    end
  end
  
  defmodule Started do
    @moduledoc false
    
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