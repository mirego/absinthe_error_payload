
v0.5.0 (2018-02-01)

### Enhancements
  * Replace Timex.parse with DateTime.from_iso8601. This eliminates Timex as a dependency.
  * Now Supports Absinthe.Resolution errors in build_payload/2 (thanks @thermech !)

### BugFixes

v0.4.0 (2017-08-03)

### Enhancements
  * `Payload.convert_to_payload` is now public and can be used to generate payloads in the same manner as the `build_payload` middleware

### BugFixes

  * fixed issue with Boolean values not comparing properly

v0.3.0 (2017-07-17)

### Enhancements
  * nil values can be compared for all types
  * convert_message is now public and can be used to generate ValidationMessages through `Ecto.Changeset.traverse_errors`

### BugFixes

  * fixed issue with NaiveDateTime values not comparing properly

v0.2.3 (2017-07-05)

### Enhancements
  * add nillable type to `assert_equivalent_graphql`

v0.2.2 (2017-06-08)

### BugFixes

  * fixed Bug where field names were not showing up in graphql responses due to `:key` vs `:field` differences

### Enhancements
  * improve messages on failure within `assert_mutation_error` and `assert_mutation_success`
  * Various doc improvements + typo fixes

v0.2.1 (2017-06-04)

### BugFixes

  * convert Timex to a test only dependency
  * Various doc improvements + typo fixes

v0.2.0 (2017-06-04)

### Enhancements

  * Remove inflex as a dependency
  * Match %ValidationMessage as an error payload without an error tuple
  * Various doc improvements + typo fixes
  * Published to Hex.pm


v0.1.0 (2017-06-03)

### Initial Release

  * Support for single object mutations
