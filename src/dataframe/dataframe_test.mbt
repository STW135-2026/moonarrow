///|
fn sample_frame() -> @dataframe.DataFrame {
  let schema = @types.Schema::new([
    @types.Field::new("city", @types.Utf8, nullable=false),
    @types.Field::new("temperature", @types.Int32),
    @types.Field::new("active", @types.Boolean),
  ]).unwrap()
  let batch = @record_batch.RecordBatch::new(schema, [
    @record_batch.Utf8(
      @array.Utf8Array::from_values(["Shenzhen", "Paris", "Tokyo"]),
    ),
    @record_batch.Int32(
      @array.Int32Array::from_options([Some(31), None, Some(27)]),
    ),
    @record_batch.Bool(
      @array.BoolArray::from_options([Some(true), None, Some(false)]),
    ),
  ]).unwrap()
  @dataframe.DataFrame::from_record_batch(batch)
}

///|
test "dataframe pipelines filter projection and limit" {
  let frame = sample_frame()
  let selected = frame
    .where_int32_gt("temperature", 25)
    .unwrap()
    .select(["city", "temperature"])
    .unwrap()
    .limit(1)
    .unwrap()
  assert_eq(selected.row_count(), 1)
  assert_eq(selected.column_count(), 2)
  guard selected.column("city") is Some(@record_batch.Utf8(city)) else {
    fail("city should exist")
  }
  assert_eq(city.to_options(), [Some("Shenzhen")])
  assert_eq(selected.sum_int32("temperature"), Ok(Some(31L)))
  assert_eq(selected.mean_int32("temperature"), Ok(Some(31.0)))
}

///|
test "dataframe reports column and type errors" {
  let frame = sample_frame()
  assert_eq(
    frame.select(["missing"]),
    Err(@dataframe.ColumnNotFound("missing")),
  )
  assert_eq(
    frame.filter_by_bool("temperature"),
    Err(
      @dataframe.ExpectedColumnType("temperature", @types.Boolean, @types.Int32),
    ),
  )
  assert_eq(frame.limit(-1), Err(@dataframe.InvalidLimit(-1)))
}

///|
test "boolean filters treat null as false" {
  let filtered = sample_frame().filter_by_bool("active").unwrap()
  assert_eq(filtered.row_count(), 1)
  guard filtered.column("city") is Some(@record_batch.Utf8(city)) else {
    fail("city should exist")
  }
  assert_eq(city.to_options(), [Some("Shenzhen")])
}
