defmodule AbsintheErrorPayload.ChangesetParser do
  @moduledoc """
  Converts an ecto changeset into a list of validation errors structs.
  Currently *does not* support nested errors
  """

  import Ecto.Changeset, only: [traverse_errors: 2]
  alias AbsintheErrorPayload.ValidationMessage

  @doc """
  Generate a list of `AbsintheErrorPayload.ValidationMessage` structs from changeset errors

  For examples, please see the test cases in the github repo.
  """
  def extract_messages(changeset) do
    changeset
    |> reject_replaced_changes()
    |> traverse_errors(&construct_traversed_message/3)
    |> Enum.to_list()
    |> Enum.flat_map(&handle_nested_errors/1)
  end

  defp reject_replaced_changes(values) when is_list(values) do
    values
    |> Enum.map(&reject_replaced_changes/1)
    |> Enum.reject(&match?(%Ecto.Changeset{action: :replace}, &1))
  end

  defp reject_replaced_changes(%{changes: changes} = changeset) do
    Enum.reduce(changes, changeset, fn {key, value}, acc ->
      %{acc | changes: Map.put(acc.changes, key, reject_replaced_changes(value))}
    end)
  end

  defp reject_replaced_changes(value), do: value

  defp handle_nested_errors({parent_field, values}) when is_map(values) do
    Enum.flat_map(values, fn {field, value} ->
      field_with_parent = construct_field(parent_field, field)
      handle_nested_errors({field_with_parent, value})
    end)
  end

  defp handle_nested_errors({parent_field, values}) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.flat_map(&handle_nested_error(parent_field, &1))
  end

  defp handle_nested_errors({_field, values}), do: values

  defp handle_nested_error(parent_field, {%ValidationMessage{} = value, _index}) do
    [%{value | field: parent_field}]
  end

  defp handle_nested_error(parent_field, {many_values, index}) do
    Enum.flat_map(many_values, fn {field, values} ->
      field_with_index = construct_field(parent_field, field, index: index)
      handle_nested_errors({field_with_index, values})
    end)
  end

  defp construct_traversed_message(_changeset, field, {message, opts}) do
    construct_message(field, {message, opts})
  end

  defp construct_field(parent_field, field, options \\ []) do
    :absinthe_error_payload
    |> Application.get_env(:field_constructor)
    |> apply(:error, [parent_field, field, options])
  end

  @doc """
  Generate a single `AbsintheErrorPayload.ValidationMessage` struct from a changeset.

  This method is designed to be used with `Ecto.Changeset.traverse_errors` to generate a map of structs.

  ## Examples

      error_map = Changeset.traverse_errors(fn(changeset, field, error) ->
        AbsintheErrorPayload.ChangesetParser.construct_message(field, error)
      end)
      error_list = Enum.flat_map(error_map, fn({_, messages}) -> messages end)

  """
  def construct_message(field, error_tuple)

  def construct_message(field, {message, opts}) do
    options = build_opts(opts)

    %ValidationMessage{
      code: to_code({message, opts}),
      field: construct_field(field, nil),
      key: field,
      template: message,
      message: interpolate_message({message, options}),
      options: to_key_value(options)
    }
  end

  defp to_key_value(opts) do
    Enum.map(opts, fn {key, value} ->
      %{
        key: key,
        value: interpolated_value_to_string(value)
      }
    end)
  end

  defp build_opts(opts) do
    opts
    |> Keyword.drop([:validation, :max, :is, :min, :code])
    |> Map.new()
  end

  @doc """
  Inserts message variables into message.
  Code inspired by Phoenix DataCase.on_errors/1 boilerplate.

  ## Examples

      iex> interpolate_message({"length should be between %{one} and %{two}", %{one: "1", two: "2", three: "3"}})
      "length should be between 1 and 2"
      iex> interpolate_message({"is already taken: %{fields}", %{fields: [:one, :two]}})
      "is already taken: one,two"

  """
  def interpolate_message({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", interpolated_value_to_string(value))
    end)
  end

  defp interpolated_value_to_string([item | _] = value) when is_atom(item) do
    value
    |> Enum.map(&to_string(&1))
    |> interpolated_value_to_string()
  end

  defp interpolated_value_to_string(value) when is_list(value), do: Enum.join(value, ",")
  defp interpolated_value_to_string(value) when is_tuple(value), do: Enum.join(Tuple.to_list(value), "-")

  defp interpolated_value_to_string({:parameterized, Ecto.Enum, %{on_load: mappings}}),
    do: mappings |> Map.values() |> Enum.join(",")

  defp interpolated_value_to_string(value), do: to_string(value)

  @doc """
  Generate unique code for each validation type.

  Expects an array of validation options such as those supplied
  by `Ecto.Changeset.traverse_errors/2`, with the addition of a message key containing the message string.
  Messages are required for several validation types to be identified.

  ## Supported

  - `:cast` - generated by `Ecto.Changeset.cast/3`
  - `:association` - generated by `Ecto.Changeset.assoc_constraint/3`, `Ecto.Changeset.cast_assoc/3`, `Ecto.Changeset.put_assoc/3`,  `Ecto.Changeset.cast_embed/3`, `Ecto.Changeset.put_embed/3`
  - `:acceptance` - generated by `Ecto.Changeset.validate_acceptance/3`
  - `:confirmation` - generated by `Ecto.Changeset.validate_confirmation/3`
  - `:length` - generated by `Ecto.Changeset.validate_length/3` when the `:is` option fails validation
  - `:min` - generated by `Ecto.Changeset.validate_length/3` when the `:min` option fails validation
  - `:max` - generated by `Ecto.Changeset.validate_length/3` when the `:max` option fails validation
  - `:less_than_or_equal_to` - generated by `Ecto.Changeset.validate_length/3` when the `:less_than_or_equal_to` option fails validation
  - `:less_than` - generated by `Ecto.Changeset.validate_length/3` when the `:less_than` option fails validation
  - `:greater_than_or_equal_to` - generated by `Ecto.Changeset.validate_length/3` when the `:greater_than_or_equal_to` option fails validation
  - `:greater_than` - generated by `Ecto.Changeset.validate_length/3` when the `:greater_than` option fails validation
  - `:equal_to` - generated by `Ecto.Changeset.validate_length/3` when the `:equal_to` option fails validation
  - `:exclusion` - generated by `Ecto.Changeset.validate_exclusion/4`
  - `:inclusion` - generated by `Ecto.Changeset.validate_inclusion/4`
  - `:required` - generated by `Ecto.Changeset.validate_required/3`
  - `:subset` - generated by `Ecto.Changeset.validate_subset/4`
  - `:unique` - generated by `Ecto.Changeset.unique_constraint/3`
  - `:foreign` -  generated by `Ecto.Changeset.foreign_key_constraint/3`
  - `:no_assoc_constraint` -  generated by `Ecto.Changeset.no_assoc_constraint/3`
  - `:unknown` - supplied when validation cannot be matched. This will also match any custom errors added through
  `Ecto.Changeset.add_error/4`, `Ecto.Changeset.validate_change/3`, and `Ecto.Changeset.validate_change/4`

  """
  def to_code({message, validation_options}) do
    validation_options
    |> Enum.into(%{message: message})
    |> validation_options_to_code()
  end

  defp validation_options_to_code(%{code: code}), do: code
  defp validation_options_to_code(%{validation: :cast}), do: :cast
  defp validation_options_to_code(%{validation: :required}), do: :required
  defp validation_options_to_code(%{validation: :format}), do: :format
  defp validation_options_to_code(%{validation: :inclusion}), do: :inclusion
  defp validation_options_to_code(%{validation: :exclusion}), do: :exclusion
  defp validation_options_to_code(%{validation: :subset}), do: :subset
  defp validation_options_to_code(%{validation: :acceptance}), do: :acceptance
  defp validation_options_to_code(%{validation: :confirmation}), do: :confirmation
  defp validation_options_to_code(%{validation: :length, kind: :is}), do: :length
  defp validation_options_to_code(%{validation: :length, kind: :min}), do: :min
  defp validation_options_to_code(%{validation: :length, kind: :max}), do: :max

  defp validation_options_to_code(%{validation: :number, message: message}) do
    cond do
      String.contains?(message, "less than or equal to") -> :less_than_or_equal_to
      String.contains?(message, "greater than or equal to") -> :greater_than_or_equal_to
      String.contains?(message, "less than") -> :less_than
      String.contains?(message, "greater than") -> :greater_than
      String.contains?(message, "equal to") -> :equal_to
      true -> :unknown
    end
  end

  defp validation_options_to_code(%{message: "is invalid", type: _}), do: :association

  defp validation_options_to_code(%{message: "has already been taken"}), do: :unique
  defp validation_options_to_code(%{message: "does not exist"}), do: :foreign
  defp validation_options_to_code(%{message: "is still associated with this entry"}), do: :no_assoc

  defp validation_options_to_code(_unknown) do
    :unknown
  end
end
