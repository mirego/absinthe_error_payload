defmodule AbsintheErrorPayload.TestHelperTest do
  @moduledoc """
  Test graphql result test helpers

  """
  use ExUnit.Case
  import AbsintheErrorPayload.TestHelper
  alias AbsintheErrorPayload.ValidationMessage

  @time DateTime.utc_now()
  @naive NaiveDateTime.utc_now()
  def fields do
    %{
      date: :date,
      naive: :date,
      string: :string,
      integer: :integer,
      float: :float,
      boolean1: :boolean,
      boolean2: :boolean,
      enum: :enum,
      nillable1: :nillable,
      nillable2: :nillable
    }
  end

  def nested_fields do
    %{
      root: :string,
      single: %{
        string: :string,
        integer: :integer,
        nillable: :nillable
      }
    }
  end

  def input do
    %{
      date: @time,
      naive: @naive,
      string: "foo bar baz",
      integer: 23,
      float: 10.32,
      boolean1: false,
      boolean2: true,
      enum: "faa",
      nillable1: nil,
      nillable2: "beez"
    }
  end

  def nil_input do
    %{
      date: nil,
      naive: nil,
      string: nil,
      integer: nil,
      float: nil,
      boolean1: nil,
      enum: nil
    }
  end

  def nested_input do
    %{
      root: "root string",
      single: %{
        string: "single nested string",
        integer: 1,
        nillable: nil
      }
    }
  end

  def graphql do
    %{
      "date" => to_string(@time),
      "naive" => to_string(@naive),
      "string" => "foo bar baz",
      "integer" => 23,
      "float" => 10.32,
      "boolean1" => false,
      "boolean2" => true,
      "enum" => "FAA",
      "nillable1" => nil,
      "nillable2" => "beez"
    }
  end

  def nil_graphql do
    %{
      "date" => nil,
      "naive" => nil,
      "string" => nil,
      "integer" => nil,
      "float" => nil,
      "boolean1" => nil,
      "enum" => nil
    }
  end

  def nested_graphql do
    %{
      "root" => "root string",
      "single" => %{
        "string" => "single nested string",
        "integer" => 1,
        "nillable" => nil
      }
    }
  end

  describe "assert_equivalent_graphql/3" do
    test "all types compare" do
      assert_equivalent_graphql(input(), graphql(), fields())
    end

    test "nil compare" do
      assert_equivalent_graphql(nil_input(), nil_graphql(), fields())
    end

    test "list compare" do
      assert_equivalent_graphql(
        [input(), input()],
        [graphql(), graphql()],
        fields()
      )
    end

    test "nested fields compare" do
      assert_equivalent_graphql(nested_input(), nested_graphql(), nested_fields())
    end
  end

  describe "assert_mutation_success/3" do
    test "matches result" do
      mutation_response = %{
        "successful" => true,
        "messages" => [],
        "result" => graphql()
      }

      assert_mutation_success(input(), mutation_response, fields())
    end

    test "matches result with nested fields" do
      mutation_response = %{
        "successful" => true,
        "messages" => [],
        "result" => nested_graphql()
      }

      assert_mutation_success(nested_input(), mutation_response, nested_fields())
    end
  end

  describe "assert_mutation_failure/3" do
    test "matches messages" do
      mutation_response = %{
        "successful" => false,
        "messages" => [
          %{"key" => "test", "field" => "test", "options" => [], "code" => "unknown", "message" => "an error", "template" => "an error"}
        ],
        "result" => nil
      }

      message = %ValidationMessage{code: :unknown, message: "an error", template: "an error"}
      assert_mutation_failure([message], mutation_response, [:code, :message, :template])
    end

    test "matches partial messages" do
      mutation_response = %{
        "successful" => false,
        "messages" => [
          %{"code" => "unknown", "message" => "an error", "template" => "an error"}
        ],
        "result" => nil
      }

      message = %ValidationMessage{code: :unknown, message: "an error", template: "an error"}
      assert_mutation_failure([message], mutation_response, [:code, :message, :template])
    end
  end
end
