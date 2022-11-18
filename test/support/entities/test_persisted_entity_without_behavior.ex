defmodule TestPersistedEntityWithoutBehavior do
  @moduledoc false

  use Reactive.Entities.PersistedEntity

  defmodule Commands do
    @moduledoc false

    defmodule Start do
      @moduledoc false

      defstruct title: nil
    end

    defmodule GetTitle do
      @moduledoc false

      defstruct id: nil
    end
  end

  defmodule Events do
    @moduledoc false

    defmodule Started do
      @moduledoc false

      defstruct title: nil
    end
  end

  defmodule Responses do
    @moduledoc false

    defmodule StartResponse do
      @moduledoc false

      defstruct title: nil
    end

    defmodule GetTitleResponse do
      @moduledoc false

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
