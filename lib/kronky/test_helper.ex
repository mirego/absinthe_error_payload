defmodule Kronky.TestHelper do
  @moduledoc """
  This module defines assertions and helpers to use when testing graphql.

  """

  import ExUnit.Assertions
  require Logger

  @doc """
  Returns a map with all keys and values set to strings, which is close to how the
  raw graphql result is returned.

  Numbers are always stringified as this function has no insight into the graphql schema.
  This is compensated for in `assert_equivalent_graphql/3`, which has context about
  expected data types.

  Associations are returned as "association" if not preloaded.
  """
  def to_stringified_map(%DateTime{} = fixture), do: to_string(fixture)
  def to_stringified_map(%NaiveDateTime{} = fixture), do: to_string(fixture)

  def to_stringified_map(%{__struct__: _} = fixture) do
    fixture
    |> Map.from_struct()
    |> Map.delete(:__meta__)
    |> to_stringified_map
  end

  def to_stringified_map(%{} = fixture) do
    fixture
    |> Enum.map(&stringify_key_and_value/1)
    |> Enum.into(%{})
  end

  def to_stringified_map(list) when is_list(list) do
    list
    |> Enum.map(&to_stringified_map/1)
  end

  def to_stringified_map(nil), do: ""

  def to_stringified_map(other), do: "#{other}"

  defp stringify_key_and_value({k, %DateTime{} = v}), do: {"#{k}", "#{v}"}
  defp stringify_key_and_value({k, %NaiveDateTime{} = v}), do: {"#{k}", NaiveDateTime.to_string(v)}
  defp stringify_key_and_value({k, %Ecto.Association.NotLoaded{}}), do: {"#{k}", "association"}
  defp stringify_key_and_value({k, true}), do: {"#{k}", true}
  defp stringify_key_and_value({k, false}), do: {"#{k}", false}
  defp stringify_key_and_value({k, nil}), do: {"#{k}", ""}

  defp stringify_key_and_value({k, v}) when is_map(v) do
    {"#{k}", to_stringified_map(v)}
  end

  defp stringify_key_and_value({k, v}) when is_list(v) do
    {"#{k}", to_stringified_map(v)}
  end

  defp stringify_key_and_value({k, v}) when is_bitstring(v), do: {"#{k}", "#{v}"}
  defp stringify_key_and_value({k, v}) when is_number(v), do: {"#{k}", "#{v}"}
  defp stringify_key_and_value({k, v}) when is_atom(v), do: {"#{k}", "#{v}"}

  defp stringify_key_and_value({k, v}) do
    # Logger.warn("unknown type to stringify: key #{inspect(k)}  value #{inspect(v)}")
    {"#{k}", "#{v}"}
  end

  defp parse_iso_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> datetime
      {:error, _} -> :error
    end
  end

  @doc "compares ISO Extended formatted strings"
  def assert_similar_times(first, second) do
    first = parse_iso_datetime(first)
    second = parse_iso_datetime(second)

    case {first, second} do
      {:error, _} -> false
      {_, :error} -> false
      {first, second} -> DateTime.compare(first, second) == :eq
    end
  end

  defp camelize(v), do: v |> to_string() |> Absinthe.Utils.camelize(lower: true)

  defp expected_value(field, expected), do: Map.get(expected, "#{field}")
  defp response_value(field, response), do: Map.get(response, "#{camelize(field)}")

  defp value_tuple({field, type}, expected, response) do
    {field, type, expected_value(field, expected), response_value(field, response)}
  end

  defp assert_values_match({field, _, nil, response}) do
    assert {field, nil} == {field, response}
  end

  defp assert_values_match({_, _, "", nil}), do: nil

  defp assert_values_match({_field, :date, expected, response}) do
    assert_similar_times(expected, response)
  end

  defp assert_values_match({field, :enum, expected, response}) do
    assert {field, String.upcase(expected)} == {field, response}
  end

  defp assert_values_match({field, :integer, expected, response}) do
    {integer_value, _} = Integer.parse(expected)
    assert {field, integer_value} == {field, response}
  end

  defp assert_values_match({field, :float, expected, response}) do
    {float_value, _} = Float.parse(expected)
    assert {field, float_value} == {field, response}
  end

  defp assert_values_match({field, :nillable, expected, response}) do
    expected = if expected == "", do: nil, else: expected
    assert {field, expected} == {field, response}
  end

  defp assert_values_match({field, :boolean, expected, response}) do
    assert {field, expected} == {field, response}
  end

  defp assert_values_match({field, _type, expected, response}) do
    assert {field, expected} == {field, response}
  end

  @doc """
  Compares a expected list, map or struct to a graphql response.

  This function uses a field definition that specifies the expected field type
  of the data. This performs some simple transforms to properly compare values, including:

  - camelCasing field names
  - coverting all non-int values to strings, including converting `false` to `"false"`
  - uppercasing enum field responses
  - parsing date types as ISO Extended format strings

  Supported field types are: :string, :float, :integer, :enum, :date, :list, :boolean

  ## Example

      query = "{ user(id: \\"1\\")
        {
          firstName
          lastName
          age
        }
      }
      "
      {:ok, %{data: data}} = evaluate_graphql(query)

      user_fields = %{first_name: :string, last_name: string, age: integer}
      expected = %User{first_name: "Lilo", last_name: "Pelekai", age: 6}
      %{"user" => result} = data
      assert_equivalent_graphql(expected, result, user_fields)


  """
  def assert_equivalent_graphql(expected, response, %{} = fields) when is_list(expected) do
    assert is_list(response), "expected a list, recieved #{inspect(response)}"

    assert Enum.count(expected) == Enum.count(response),
           "Expected #{Enum.count(expected)} items, recieved #{inspect(response)}"

    for {e, m} <- Enum.zip(expected, response) do
      assert_equivalent_graphql(e, m, fields)
    end
  end

  def assert_equivalent_graphql(expected, response, %{} = fields) when is_map(expected) do
    stringified = to_stringified_map(expected)

    fields
    |> Enum.to_list()
    |> Enum.map(fn field_tuple -> value_tuple(field_tuple, stringified, response) end)
    |> Enum.each(&assert_values_match/1)
  end

  @doc """
  Compares an expected map to a successful mutation response, as generated by `Kronky.Payload.build_payload/2`

  ## Example

  ```elixir
    query =
      "
      mutation{
        createUser(
          user: {
            age: 6
            firstName: "Lilo"
            lastName: "Pelekai"
          }
        ){
          successful
          messages {
            field
            message
            code
          }
          result {
            id
            age
            firstName
            lastName
          }
        }
      }
      "

    assert {:ok, %{data: data}} = evaluate_graphql(query)
    assert %{"createUser" => payload} = data

    user_fields = %{first_name: :string, last_name: string, age: integer}
    expected = %User{first_name: "Lilo", last_name: "Pelekai", age: 6}
    assert_mutation_success(expected, payload, user_fields)
    assert %User{} = Repo.get(User, payload["result"]["id"])
  ```

  """
  def assert_mutation_success(expected, payload, %{} = fields) do
    assert %{"successful" => true} = payload
    refute nil == payload["result"]

    assert_equivalent_graphql(expected, payload["result"], fields)
  end

  @doc """
  Compares an expected list of validation errors to a successful mutation response, as generated by `Kronky.Payload.build_payload/2`

  Optionally pass a subset of fields to compare - by default all `Kronky.ValidationMessage` fields are included,
  so you will need to use this parameter if you are returning fewer fields.

  ## Example

  ```elixir
    user = insert(:user, %{first_name: "Stitch"})
    query =
      "
      mutation{
        updateUser(
        id: \#{user.id}
        user: {
          age: 0
        }
        ){
          successful
          messages {
            field
            message
            code
          }
          result {
            id
            firstName
            age
            updatedAt
          }
        }
      }
      "

    assert {:ok, %{data: data}} = evaluate_graphql(query)
    assert %{"updateUser" => payload} = data

    expected = %ValidationMessage{
      code: :greater_than, field: :age, message: "must be greater than 0"
    }

    assert_mutation_failure([expected], payload, [:field, :message, :code])
  ```
  """
  def assert_mutation_failure(expected, payload, only \\ nil) do
    assert %{"successful" => false} = payload
    assert %{"result" => nil} = payload

    assert_equivalent_graphql(expected, payload["messages"], validation_message_fields(only))
  end

  @doc """
  Mapping of `Kronky.ValidationMessage` fields used by assert_mutation_failure
  """
  def validation_message_fields() do
    %{
      field: :string,
      message: :string,
      code: :string,
      template: :string,
      options: :list,
      key: :string,
      value: :string
    }
  end

  @doc """
  Subset of Mapping of `Kronky.ValidationMessage` fields used by assert_mutation_failure
  """
  def validation_message_fields(nil), do: validation_message_fields()

  def validation_message_fields(only) do
    Map.take(validation_message_fields(), only)
  end
end
