defmodule AbsintheErrorPayload.Payload do
  @moduledoc """
  Absinthe Middleware to build a mutation payload response.

  AbsintheErrorPayload mutation responses (aka "payloads") have three fields

  - `successful` - Indicates if the mutation completed successfully or not. Boolean.
  - `messages` - a list of validation errors. Always empty on success
  - `result` - the data object that was created/updated/deleted on success. Always nil when unsuccesful


  ## Usage

  In your schema file

  1. `import AbsintheErrorPayload.Payload`
  2. `import_types AbsintheErrorPayload.ValidationMessageTypes`
  3. create a payload object for each object using `payload_object(payload_name, object_name)`
  4. create a mutation that returns the payload object. Add the payload middleware after the resolver.
  ```
  field :create_user, type: :user_payload, description: "add a user" do
    arg :user, :create_user_params
    resolve &UserResolver.create/2
    middleware &build_payload/2
  end
  ```

  ## Example Schema

  Object Schema:

  ```elixir

  defmodule MyApp.Schema.User do
  @moduledoc false

  use Absinthe.Schema.Notation
  import AbsintheErrorPayload.Payload
  import_types AbsintheErrorPayload.ValidationMessageTypes

  alias MyApp.Resolvers.User, as: UserResolver

  object :user, description: "Someone on our planet" do
    field :id, non_null(:id), description: "unique identifier"
    field :first_name, non_null(:string), description: "User's first name"
    field :last_name, :string, description: "Optional Last Name"
    field :age, :integer, description: "Age in Earth years"
    field :inserted_at, :time, description: "Created at"
    field :updated_at, :time, description: "Last updated at"
  end

  input_object :create_user_params, description: "create a user" do
    field :first_name, non_null(:string), description: "Required first name"
    field :last_name, :string, description: "Optional last name"
    field :age, :integer, description: "Age in Earth years"
  end

  payload_object(:user_payload, :user)

  object :user_mutations do

    field :create_user, type: :user_payload, description: "Create a new user" do
      arg :user, :create_user_params
      resolve &UserResolver.create/2
      middleware &build_payload/2
    end
  end
  ```

  In your main schema file

  ```
  import_types MyApp.Schema.User

  mutation do
   ...
   import_fields :user_mutations
  end
  ```

  ## Alternate Use

  If you'd prefer not to use the middleware style, you can generate AbsintheErrorPayload payloads
  in your resolver instead. See `success_payload/1` and `error_payload/1` for examples.

  """

  @enforce_keys [:successful]
  defstruct successful: nil, messages: [], result: nil

  use Absinthe.Schema.Notation

  import AbsintheErrorPayload.ChangesetParser

  alias __MODULE__
  alias AbsintheErrorPayload.ValidationMessage

  @doc """
  Create a payload object definition

  Each object that can be mutated will need its own graphql response object
  in order to return typed responses.  This is a helper method to generate a
  custom payload object

  ## Usage

    payload_object(:user_payload, :user)

  is the equivalent of

  ```elixir
  object :user_payload do
    field :successful, non_null(:boolean), description: "Indicates if the mutation completed successfully or not. "
    field :messages, list_of(:validation_message), description: "A list of failed validations. May be blank or null if mutation succeeded."
    field :result, :user, description: "The object created/updated/deleted by the mutation"
  end
  ```

  This method must be called after `import_types AbsintheErrorPayload.MutationTypes` or it will fail due to `:validation_message` not being defined.
  """
  defmacro payload_object(payload_name, result_object_name) do
    quote location: :keep do
      object unquote(payload_name) do
        field(:successful, non_null(:boolean), description: "Indicates if the mutation completed successfully or not. ")
        field(:messages, non_null(list_of(non_null(:validation_message))), description: "A list of failed validations. May be blank or null if mutation succeeded.")
        field(:result, unquote(result_object_name), description: "The object created/updated/deleted by the mutation. May be null if mutation failed.")
      end
    end
  end

  @doc ~S'''
  Convert a resolution value to a mutation payload

  To be used as middleware by Absinthe.Graphql. It should be placed immediatly after the resolver.

  The middleware will automatically transform an invalid changeset into validation errors.

  Your resolver could then look like:

  ```elixir
  @doc """
  Creates a new user

  Results are wrapped in a result monad as expected by absinthe.
  """
  def create(%{user: attrs}, _resolution) do
    case UserContext.create_user(attrs) do
      {:ok, user} -> {:ok, user}
      {:error, %Ecto.Changeset{} = changeset} -> {:ok, changeset}
    end
  end
  ```

  The build payload middleware will also accept error tuples with single or lists of
  `AbsintheErrorPayload.ValidationMessage` or string errors. However, lists and strings will need to be wrapped in
  an :ok tuple or they will be seen as errors by graphql.

  An example resolver could look like:

  ```
  @doc """
  updates an existing user.

  Results are wrapped in a result monad as expected by absinthe.
  """
  def update(%{id: id, user: attrs}, _resolution) do
    case UserContext.get_user(id) do
      nil -> {:ok, %ValidationMessage{field: :id, code: "not found", message: "does not exist"}}
      user -> do_update_user(user, attrs)
    end
  end

  defp do_update_user(user, attrs) do
    case UserContext.update_user(user, attrs) do
      {:ok, user} -> {:ok, user}
      {:error, %Ecto.Changeset{} = changeset} -> {:ok, changeset}
    end
  end
  ```

  Valid formats are:
  ```
  %ValidationMessage{}
  {:error, %ValidationMessage{}}
  {:error, [%ValidationMessage{},%ValidationMessage{}]}
  {:error, "This is an error"}
  {:error, :error_atom}
  {:error, ["This is an error", "This is another error"]}
  ```

  ## Alternate Use

  If you'd prefer not to use the middleware style, you can generate AbsintheErrorPayload payloads
  in your resolver instead. See `convert_to_payload/1`, `success_payload/1` and `error_payload/1` for examples.

  '''
  def build_payload(%{errors: [%Ecto.Changeset{} = errors]} = resolution, _config) do
    result = convert_to_payload(errors)
    %{resolution | value: result, errors: []}
  end

  def build_payload(%{value: value, errors: []} = resolution, _config) do
    result = convert_to_payload(value)
    %{resolution | value: result, errors: []}
  end

  def build_payload(%{errors: errors} = resolution, _config) do
    result = convert_to_payload({:error, errors})
    %{resolution | value: result, errors: []}
  end

  @doc ~S'''
  Direct converter from value to a `Payload` struct.

  This function will automatically transform an invalid changeset into validation errors.

  Changesets, error tuples and lists of `AbsintheErrorPayload.ValidationMessage` will be identified
  as errors and will generate an error payload.

  Error formats are:
  ```
  %Ecto.Changeset{valid?: false}
  %ValidationMessage{}
  {:error, %ValidationMessage{}}
  {:error, [%ValidationMessage{},%ValidationMessage{}]}
  {:error, "This is an error"}
  {:error, :error_atom}
  {:error, ["This is an error", "This is another error"]}
  ```

  All other values will be converted to a success payload.
  or string errors. However, lists and strings will need to be wrapped in
  an :ok tuple or they will be seen as errors by graphql.

  An example use could look like:

  ```
  @doc """
  Load a user matching an id

  Results are wrapped in a result monad as expected by absinthe.
  """
  def get_user(%{id: id}, _resolution) do
    case UserContext.get_user(id) do
      nil -> %ValidationMessage{field: :id, code: "not found", message: "does not exist"}}
      user -> user
    end
    |> AbsintheErrorPayload.Payload.convert_to_payload()
  end
  '''
  def convert_to_payload({:error, %ValidationMessage{} = message}) do
    error_payload(message)
  end

  def convert_to_payload(%ValidationMessage{} = message) do
    error_payload(message)
  end

  def convert_to_payload({:error, message}) when is_binary(message) do
    message
    |> generic_validation_message()
    |> error_payload()
  end

  def convert_to_payload({:error, message}) when is_atom(message), do: convert_to_payload({:error, "#{message}"})

  def convert_to_payload({:error, list}) when is_list(list), do: error_payload(list)

  def convert_to_payload(%Ecto.Changeset{valid?: false} = changeset) do
    changeset
    |> extract_messages()
    |> error_payload()
  end

  def convert_to_payload(value), do: success_payload(value)

  @doc ~S'''
  Generates a mutation error payload.

  ## Examples

      iex> error_payload(%ValidationMessage{code: "required", field: "name"})
      %Payload{successful: false, messages: [%ValidationMessage{code: "required", field: "name"}]}

      iex> error_payload([%ValidationMessage{code: "required", field: "name"}])
      %Payload{successful: false, messages: [%ValidationMessage{code: "required", field: "name"}]}

  ## Usage

  If you prefer not to use the Payload.middleware, you can use this method in your resolvers instead.

  ```elixir

  @doc """
  updates an existing user.

  Results are wrapped in a result monad as expected by absinthe.
  """
  def update(%{id: id, user: attrs}, _resolution) do
    case UserContext.get_user(id) do
      nil -> {:ok, error_payload([%ValidationMessage{field: :id, code: "not found", message: "does not exist"}])}
      user -> do_update_user(user, attrs)
    end
  end

  defp do_update_user(user, attrs) do
    case UserContext.update_user(user, attrs) do
      {:ok, user} -> {:ok, success_payload(user)}
      {:error, %Ecto.Changeset{} = changeset} -> {:ok, error_payload(changeset)}
    end
  end
  ```
  '''
  def error_payload(%ValidationMessage{} = message), do: error_payload([message])

  def error_payload(messages) when is_list(messages) do
    messages = Enum.map(messages, &prepare_message/1)
    %Payload{successful: false, messages: messages}
  end

  @doc "convert validation message field to camelCase format used by graphQL"
  def convert_field_name(%ValidationMessage{} = message) do
    field =
      cond do
        message.field == nil -> camelized_name(message.key)
        message.key == nil -> camelized_name(message.field)
        true -> camelized_name(message.field)
      end

    %{message | field: field, key: field}
  end

  defp camelized_name(nil), do: nil

  defp camelized_name(field) do
    field
    |> to_string()
    |> Absinthe.Utils.camelize(lower: true)
  end

  defp prepare_message(%ValidationMessage{} = message) do
    convert_field_name(message)
  end

  defp prepare_message(message) when is_binary(message) do
    generic_validation_message(message)
  end

  defp prepare_message(message) when is_atom(message) do
    generic_validation_message("#{message}")
  end

  defp prepare_message(message) do
    raise ArgumentError, "Unexpected validation message: #{inspect(message)}"
  end

  @doc ~S'''
  Generates a success payload.

  ## Examples

      iex> success_payload(%User{first_name: "Stich", last_name: "Pelekai", id: 626})
      %Payload{successful: true, result: %User{first_name: "Stich", last_name: "Pelekai", id: 626}}

  ## Usage

  If you prefer not to use the `build_payload/2` middleware, you can use this method in your resolvers instead.

  ```elixir
  @doc """
  Creates a new user

  Results are wrapped in a result monad as expected by absinthe.
  """
  def create(%{user: attrs}, _resolution) do
    case UserContext.create_user(attrs) do
      {:ok, user} -> {:ok, success_payload(user)}
      {:error, %Ecto.Changeset{} = changeset} -> {:ok, error_payload(changeset)}
    end
  end
  ```

  '''
  def success_payload(result) do
    %Payload{successful: true, result: result}
  end

  defp generic_validation_message(message) do
    %ValidationMessage{
      code: :unknown,
      field: nil,
      template: message,
      message: message,
      options: []
    }
  end
end
