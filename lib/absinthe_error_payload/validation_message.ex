defmodule AbsintheErrorPayload.ValidationMessage do
  @moduledoc """
  Stores validation message information.

  ## Fields

  ### :field
  The input field that the error applies to. The field can be used to
  identify which field the error message should be displayed next to in the
  presentation layer.

  If there are multiple errors to display for a field, multiple validation
  messages will be in the result.

  This field may be nil in cases where an error cannot be applied to a specific field.

  ### :message
  A friendly error message, appropriate for display to the end user.

  The message is interpolated to include the appropriate variables.

  Example: `"Username must be at least 10 characters"`

  ### :template
  A template used to generate the error message, with placeholders for option substitution.

  Example: `"Username must be at least %{count} characters"`

  ### :code
  A unique error code for the type of validation that failed. This field must be provided.

  See `AbsintheErrorPayload.ChangesetParser.to_code/1` for built in codes corresponding to most Ecto validations.

  ### :options
  A list of key value pair to be applied to a validation message template.
  The structure is a list of `%{key: _, value: _}` to be able to serialize to a GraphQL type

  ### :key
  Deprecated, use :field instead
  """

  @type t() :: %__MODULE__{
    field: atom() | String.t() | nil,
    key: atom() | String.t() | nil,
    code: atom() | String.t(),
    options: [option()],
    template: String.t(),
    message: String.t()
  }

  @type option() :: %{
    required(:key) => any(), 
    required(:value) => any()
  }

  @enforce_keys [:code]
  defstruct field: nil, key: nil, code: nil, options: [], template: "is invalid", message: "is invalid"
end
