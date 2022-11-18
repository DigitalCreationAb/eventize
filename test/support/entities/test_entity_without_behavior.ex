defmodule TestEntityWithoutBehavior do
  @moduledoc false

  use Reactive.Entities.Entity

  defmodule Commands do
    @moduledoc false

    defmodule Start do
      @moduledoc false

      defstruct title: nil
    end

    defmodule Stop do
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

    defmodule Stopped do
      @moduledoc false

      defstruct id: nil
    end
  end

  defmodule Responses do
    @moduledoc false

    defmodule StartResponse do
      @moduledoc false

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
