defmodule AbsintheErrorPayload.ChangesetParserTest do
  @moduledoc """
  Test conversion of changeset errors to ValidationMessage structs

  """
  use ExUnit.Case
  doctest(AbsintheErrorPayload.ChangesetParser, import: true)

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
      field(:language, Ecto.Enum, values: [:en, :fr])
      field(:metadata, {:array, :map})

      belongs_to(:author, Author)
      has_many(:tags, Tag)

      embeds_many :embedded_tags, EmbeddedTag, on_replace: :delete do
        field(:name)
      end
    end
  end

  defp changeset(params) do
    cast(%Post{}, params, ~w(title body upvotes decimal topics virtual)a)
  end

  defp changeset_with_embeds(params) do
    cast(
      %Post{
        embedded_tags: [
          %Post.EmbeddedTag{id: "30b2111e-6b57-45ed-bf85-ed2f41715832", name: "foo"}
        ]
      },
      params,
      ~w(title body upvotes decimal topics virtual)a
    )
  end

  describe "interpolate_message/1" do
    test "interpolates correctly" do
      result = ChangesetParser.interpolate_message({"Test %{one}", [one: "1"]})
      assert "Test 1" == result

      result = ChangesetParser.interpolate_message({"Test %{one}", %{one: "1"}})
      assert "Test 1" == result
    end
  end

  describe "multiples" do
    test "multiple fields with errors" do
      changeset =
        %{"title" => "foobar", "virtual" => "foobar", "author" => %{"name" => ""}}
        |> changeset()
        |> cast_assoc(:author,
          with: fn author, params ->
            author
            |> cast(params, ~w(name)a)
            |> validate_required(:name)
          end
        )
        |> validate_format(:title, ~r/@/)
        |> validate_length(:virtual, is: 4)

      result = ChangesetParser.extract_messages(changeset)
      assert [first, second, third] = result
      assert %ValidationMessage{field: "author.name", key: :name} = first
      assert %ValidationMessage{code: :format, field: :title, key: :title} = second
      assert %ValidationMessage{code: :length, field: :virtual, key: :virtual} = third
    end

    test "multiple fields with nested errors" do
      changeset =
        %{"title" => "foobar", "virtual" => "foobar"}
        |> changeset()
        |> validate_format(:title, ~r/@/)
        |> validate_length(:virtual, is: 4)

      result = ChangesetParser.extract_messages(changeset)
      assert [first, second] = result
      assert %ValidationMessage{code: :format, field: :title, key: :title} = first
      assert %ValidationMessage{code: :length, field: :virtual, key: :virtual} = second
    end

    test "multiple errors on one field" do
      changeset =
        %{"title" => "foobar"}
        |> changeset()
        |> validate_format(:title, ~r/@/)
        |> validate_length(:title, is: 4)

      result = ChangesetParser.extract_messages(changeset)
      assert [first, second] = result
      assert %ValidationMessage{code: :length, field: :title, key: :title} = first
      assert %ValidationMessage{code: :format, field: :title, key: :title} = second
    end
  end

  describe "nested" do
    test "nested fields with errors" do
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
      assert %ValidationMessage{code: :required, field: "author.name", key: :name} = first
    end

    test "nested fields with errors on replaced embeds_many" do
      changeset =
        %{"embedded_tags" => [%{"name" => ""}, %{"name" => "valid"}, %{"name" => ""}]}
        |> changeset_with_embeds()
        |> cast_embed(:embedded_tags,
          with: fn tag, params ->
            tag
            |> cast(params, ~w(name)a)
            |> validate_required(:name)
          end
        )

      result = ChangesetParser.extract_messages(changeset)
      assert [first, second] = result
      assert %ValidationMessage{message: "can't be blank", code: :required, field: "embedded_tags.0.name", key: :name} = first
      assert %ValidationMessage{message: "can't be blank", code: :required, field: "embedded_tags.2.name", key: :name} = second
    end

    test "nested has many fields with errors" do
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
      assert %ValidationMessage{code: :required, field: "tags.0.name", key: :name} = first
      assert %ValidationMessage{code: :required, field: "tags.1.name", key: :name} = second
    end

    test "nested nil has many fields with errors" do
      changeset =
        %{"tags" => nil}
        |> changeset()
        |> cast_assoc(:tags,
          with: fn tag, params ->
            tag
            |> cast(params, ~w(name)a)
            |> validate_required(:name)
          end
        )

      result = ChangesetParser.extract_messages(changeset)
      assert [first] = result
      assert %ValidationMessage{code: :association, field: :tags, key: :tags, message: "is invalid", options: [%{key: :type, value: "array-map"}]} = first
    end
  end

  describe "construct_message/2" do
    test "creates expected struct" do
      message = "can't be %{illegal}"
      options = [code: "foobar", illegal: "foobar"]

      message = ChangesetParser.construct_message(:title, {message, options})

      assert %ValidationMessage{} = message
      assert message.code == "foobar"
      assert message.key == :title
      assert message.field == :title
      assert message.options == [%{key: :illegal, value: "foobar"}]
      assert message.message =~ ~r/foobar/
      assert message.template =~ ~r/%{illegal}/
    end
  end

  describe "validations" do
    test "custom with code" do
      changeset =
        %{"title" => "foobar"}
        |> changeset()
        |> add_error(:title, "can't be %{illegal}", code: "foobar", illegal: "foobar")

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == "foobar"
      assert message.key == :title
      assert message.field == :title
      assert message.options == [%{key: :illegal, value: "foobar"}]
      assert message.message =~ ~r/foobar/
      assert message.template =~ ~r/%{illegal}/
    end

    test "custom without code" do
      changeset =
        %{"title" => "foobar"}
        |> changeset()
        |> add_error(:title, "can't be %{illegal}", illegal: "foobar")

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :unknown
      assert message.key == :title
      assert message.field == :title
      assert message.options == [%{key: :illegal, value: "foobar"}]
      assert message.message =~ ~r/foobar/
      assert message.template =~ ~r/%{illegal}/
    end

    test "format validation" do
      changeset =
        %{"title" => "foobar"}
        |> changeset()
        |> validate_format(:title, ~r/@/)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :format
      assert message.key == :title
      assert message.field == :title
      assert message.options == []
      assert message.message != ""
      assert message.template != ""
    end

    test "inclusion validation" do
      changeset =
        %{"title" => "hello"}
        |> changeset()
        |> validate_inclusion(:title, ~w(world))

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :inclusion
      assert message.key == :title
      assert message.field == :title
      assert message.options == [%{key: :enum, value: "world"}]
      assert message.message != ""
      assert message.template != ""
    end

    test "subset validation" do
      changeset =
        %{"topics" => ["cat", "laptop"]}
        |> changeset()
        |> validate_subset(:topics, ~w(cat dog))

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :subset
      assert message.key == :topics
      assert message.field == :topics
      assert message.options == [%{key: :enum, value: "cat,dog"}]
      assert message.message != ""
      assert message.template != ""
    end

    test "exclusion validation" do
      changeset =
        %{"title" => "world"}
        |> changeset()
        |> validate_exclusion(:title, ~w(world))

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :exclusion
      assert message.key == :title
      assert message.field == :title
      assert message.options == [%{key: :enum, value: "world"}]
      assert message.message != ""
      assert message.template != ""
    end

    test "min validation" do
      changeset =
        %{"title" => "w"}
        |> changeset()
        |> validate_length(:title, min: 2, max: 3)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :min
      assert message.key == :title
      assert message.field == :title

      assert message.options == [
               %{key: :count, value: "2"},
               %{key: :kind, value: "min"},
               %{key: :type, value: "string"}
             ]

      assert message.message =~ ~r/2/
      assert message.template =~ ~r/%{count}/
    end

    test "max validation" do
      changeset =
        %{"title" => "world"}
        |> changeset()
        |> validate_length(:title, min: 2, max: 3)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :max
      assert message.key == :title
      assert message.field == :title
      assert message.options == [%{key: :count, value: "3"}, %{key: :kind, value: "max"}, %{key: :type, value: "string"}]
      assert message.message =~ ~r/3/
      assert message.template =~ ~r/%{count}/
    end

    test "length validation" do
      changeset =
        %{"title" => "world"}
        |> changeset()
        |> validate_length(:title, is: 7)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :length
      assert message.key == :title
      assert message.field == :title

      assert message.options == [
               %{key: :count, value: "7"},
               %{key: :kind, value: "is"},
               %{key: :type, value: "string"}
             ]

      assert message.message =~ ~r/7/
      assert message.template =~ ~r/%{count}/
    end

    test "greater_than validation" do
      changeset =
        %{"upvotes" => 3}
        |> changeset()
        |> validate_number(:upvotes, greater_than: 10)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :greater_than
      assert message.key == :upvotes
      assert message.field == :upvotes
      assert message.options == [%{key: :kind, value: "greater_than"}, %{key: :number, value: "10"}]
      assert message.message =~ ~r/10/
      assert message.template =~ ~r/%{number}/
    end

    test "greater_than_or_equal_to validation" do
      changeset =
        %{"upvotes" => 3}
        |> changeset()
        |> validate_number(:upvotes, greater_than_or_equal_to: 10)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :greater_than_or_equal_to
      assert message.key == :upvotes
      assert message.field == :upvotes

      assert message.options == [
               %{key: :kind, value: "greater_than_or_equal_to"},
               %{key: :number, value: "10"}
             ]

      assert message.message =~ ~r/10/
      assert message.template =~ ~r/%{number}/
    end

    test "less_than validation" do
      changeset =
        %{"upvotes" => 3}
        |> changeset()
        |> validate_number(:upvotes, less_than: 1)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :less_than
      assert message.key == :upvotes
      assert message.field == :upvotes

      assert message.options ==
               [
                 %{key: :kind, value: "less_than"},
                 %{key: :number, value: "1"}
               ]

      assert message.message =~ ~r/1/
      assert message.template =~ ~r/%{number}/
    end

    test "less_than_or_equal_to validation" do
      changeset =
        %{"upvotes" => 3}
        |> changeset()
        |> validate_number(:upvotes, less_than_or_equal_to: 1)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :less_than_or_equal_to
      assert message.key == :upvotes
      assert message.field == :upvotes

      assert message.options == [
               %{key: :kind, value: "less_than_or_equal_to"},
               %{key: :number, value: "1"}
             ]

      assert message.message =~ ~r/1/
      assert message.template =~ ~r/%{number}/
    end

    test "equal_to validation" do
      changeset =
        %{"upvotes" => 3}
        |> changeset()
        |> validate_number(:upvotes, equal_to: 1)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :equal_to
      assert message.key == :upvotes
      assert message.field == :upvotes
      assert message.options == [%{key: :kind, value: "equal_to"}, %{key: :number, value: "1"}]
      assert message.message =~ ~r/1/
      assert message.template =~ ~r/%{number}/
    end

    test "confirmation validation" do
      changeset =
        %{"title" => "title", "title_confirmation" => "not title"}
        |> changeset()
        |> validate_confirmation(:title, required: true)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :confirmation
      assert message.key == :title_confirmation
      assert message.field == :title_confirmation
      assert message.options == []
      assert message.message != ""
      assert message.template != ""
    end

    test "acceptance validation" do
      changeset =
        %{"terms_of_service" => "false"}
        |> changeset()
        |> validate_acceptance(:terms_of_service)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :acceptance
      assert message.key == :terms_of_service
      assert message.field == :terms_of_service
      assert message.options == []
      assert message.message != ""
      assert message.template != ""
    end

    test "required validation" do
      changeset =
        %{}
        |> changeset()
        |> validate_required(:title)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :required
      assert message.key == :title
      assert message.field == :title
      assert message.options == []
      assert message.message != ""
      assert message.template != ""
    end

    test "cast validation" do
      params = %{"body" => :world}
      struct = %Post{}

      changeset = cast(struct, params, ~w(body)a)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)
      assert message.code == :cast
      assert message.key == :body
      assert message.field == :body
      assert message.options == [%{key: :type, value: "string"}]
      assert message.message != ""
      assert message.template != ""
    end

    test "cast enum" do
      params = %{"language" => :de}
      struct = %Post{}

      changeset = cast(struct, params, ~w(language)a)

      assert [%ValidationMessage{} = message] = ChangesetParser.extract_messages(changeset)

      assert message.code == :cast
      assert message.key == :language
      assert message.field == :language
      assert message.options == [%{key: :type, value: "en,fr"}]
      assert message.message != ""
      assert message.template != ""
    end
  end
end
