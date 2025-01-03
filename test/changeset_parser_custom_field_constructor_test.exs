defmodule AbsintheErrorPayload.ChangesetParserCustomFieldConstructorTest do
  @moduledoc """
  Test conversion of changeset errors to ValidationMessage structs

  """
  use ExUnit.Case, async: false

  import Ecto.Changeset

  alias AbsintheErrorPayload.ChangesetParser
  alias AbsintheErrorPayload.ValidationMessage

  # taken from Ecto.changeset tests
  defmodule Author do
    @moduledoc false
    use Ecto.Schema

    schema "author" do
      field(:name, :string)
    end
  end

  defmodule Tag do
    @moduledoc false
    use Ecto.Schema

    schema "tags" do
      field(:name, :string)
    end
  end

  defmodule Post do
    @moduledoc false
    use Ecto.Schema

    schema "posts" do
      field(:title, :string, default: "")
      field(:body)
      field(:uuid, :binary_id)
      field(:decimal, :decimal)
      field(:upvotes, :integer, default: 0)
      field(:topics, {:array, :string})
      field(:virtual, :string, virtual: true)
      field(:published_at, :naive_datetime)

      belongs_to(:author, Author)
      has_many(:tags, Tag)
    end
  end

  defp changeset(params) do
    cast(%Post{}, params, ~w(title body upvotes decimal topics virtual)a)
  end

  defmodule CustomFieldConstructor do
    @behaviour AbsintheErrorPayload.FieldConstructor

    def error(parent_field, field, options \\ [])
    def error(parent_field, nil, _options), do: "@root›#{parent_field}"
    def error(parent_field, field, index: index), do: "#{parent_field}@#{index}›#{field}"
    def error(parent_field, field, _options), do: "#{parent_field}›#{field}"
  end

  setup do
    original_field_constructor = Application.get_env(:absinthe_error_payload, :field_constructor)
    Application.put_env(:absinthe_error_payload, :field_constructor, CustomFieldConstructor)

    on_exit(fn ->
      Application.put_env(:absinthe_error_payload, :field_constructor, original_field_constructor)
    end)
  end

  describe "construct_message/2" do
    test "creates expected struct" do
      message = "can't be %{illegal}"
      options = [code: "foobar"]

      message = ChangesetParser.construct_message(:title, {message, options})

      assert %ValidationMessage{} = message
      assert message.field == "@root›title"
    end
  end

  test "nested fields" do
    changeset =
      %{"author" => %{"name" => ""}}
      |> changeset()
      |> cast_assoc(:author,
        with: fn author, params ->
          author
          |> cast(params, ~w(name)a)
          |> validate_required(:name)
        end
      )

    result = ChangesetParser.extract_messages(changeset)
    assert [first] = result
    assert %ValidationMessage{code: :required, field: "author›name", key: :name} = first
  end

  test "nested fields with index" do
    changeset =
      %{"tags" => [%{"name" => ""}, %{"name" => ""}]}
      |> changeset()
      |> cast_assoc(:tags,
        with: fn tag, params ->
          tag
          |> cast(params, ~w(name)a)
          |> validate_required(:name)
        end
      )

    result = ChangesetParser.extract_messages(changeset)
    assert [first, second] = result
    assert %ValidationMessage{code: :required, field: "tags@0›name", key: :name} = first
    assert %ValidationMessage{code: :required, field: "tags@1›name", key: :name} = second
  end
end
