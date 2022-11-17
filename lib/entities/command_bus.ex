defmodule Reactive.Entities.CommandBus do
  @moduledoc false

  @callback cast(entity_type :: :atom, id :: Any, command :: struct) :: :ok
  
  @callback call(entity_type :: :atom, id :: Any, command :: struct) :: term
end
