defmodule Kronky.TestHelperTest do
  @moduledoc """
  Test graphql result test helpers

  """
  use ExUnit.Case
  import Kronky.TestHelper
  alias Kronky.ValidationMessage

  @time DateTime.utc_now
  def fields() do
    %{
      date: :date,
      string: :string,
      integer: :integer,
      float: :float,
      boolean1: :boolean,
      boolean2: :boolean,
      enum: :enum,
    }
  end

  def input() do
    %{
      date: @time,
      string: "foo bar baz",
      integer: 23,
      float: 10.32,
      boolean1: false,
      boolean2: true,
      enum: "faa",
    }

  end

  def graphql() do
    %{
     "date" => to_string(@time),
     "string" => "foo bar baz",
     "integer" => 23,
     "float" => 10.32,
     "boolean1" => "false",
     "boolean2" => "true",
     "enum" => "FAA",
   }
  end


  describe "assert_equivalent_graphql/3" do

    test "all types compare" do
      assert_equivalent_graphql(input(), graphql(), fields())
    end

    test "list compare" do
      assert_equivalent_graphql(
        [input(), input()],
        [graphql(), graphql()],
        fields()
      )
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
  end

  describe "assert_mutation_failure/3" do

    test "matches messages" do


      mutation_response = %{
        "successful" => false,
        "messages" => [
          %{"key" => "", "options" => [], "code" => "unknown", "message" => "an error", "template" => "an error"}
          ],
        "result" => nil
      }

      message = %ValidationMessage{code: :unknown, message: "an error", template: "an error"}
      assert_mutation_failure([message], mutation_response)

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

  describe "evaluate_schema/1" do

    defmodule ValidSchema do
      @moduledoc false

      use Absinthe.Schema

      query do
        #Query type must exist
      end

      object :person do
        description "A person"
        field :name, :string
      end

    end
    evaluate_schema schema: ValidSchema

    test "creates function" do
      assert {:evaluate_graphql, 1} in __MODULE__.__info__(:exports)
    end

  end

end
