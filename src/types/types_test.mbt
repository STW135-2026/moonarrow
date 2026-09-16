///|
test "schema preserves ordered fields" {
  let schema = @types.Schema::new([
    @types.Field::new("city", @types.Utf8, nullable=false),
    @types.Field::new("temperature", @types.Float64),
  ])
  guard schema is Ok(schema) else { fail("schema should be valid") }
  assert_eq(schema.len(), 2)
  assert_eq(schema.field_index("temperature"), Some(1))
  assert_eq(schema.field(0).map(field => field.name), Some("city"))
}

///|
test "schema rejects duplicate names" {
  let schema = @types.Schema::new([
    @types.Field::new("id", @types.Int32),
    @types.Field::new("id", @types.Int64),
  ])
  assert_true(schema is Err(@types.DuplicateFieldName("id")))
}

///|
test "data type names are stable" {
  assert_eq(@types.Boolean.name(), "bool")
  assert_eq(@types.Int32.name(), "int32")
  assert_eq(@types.Utf8.name(), "utf8")
}
