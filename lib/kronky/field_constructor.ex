defmodule Kronky.FieldConstructor do
  @callback error(String.t, String.t, list()) :: String.t

  def error(parent_field, field, options \\ [])
  def error(parent_field, nil, _options), do: parent_field
  def error(parent_field, field, index: index), do: "#{parent_field}.#{index}.#{field}"
  def error(parent_field, field, _options), do: "#{parent_field}.#{field}"
end
