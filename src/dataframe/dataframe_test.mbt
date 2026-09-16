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

///|
test "dataframe filters int64 while preserving binary payloads" {
  let schema = @types.Schema::new([
    @types.Field::new("sequence", @types.Int64),
    @types.Field::new("payload", @types.Binary),
  ]).unwrap()
  let batch = @record_batch.RecordBatch::new(schema, [
    @record_batch.Int64(
      @array.Int64Array::from_options([
        Some(4_294_967_296L),
        None,
        Some(9_223_372_036_854_775_000L),
      ]),
    ),
    @record_batch.Binary(
      @array.BinaryArray::from_values([b"small", b"null", b"large"]),
    ),
  ]).unwrap()
  let filtered = @dataframe.DataFrame::from_record_batch(batch)
    .where_int64_gt("sequence", 5_000_000_000L)
    .unwrap()
  assert_eq(filtered.row_count(), 1)
  guard filtered.column("payload") is Some(@record_batch.Binary(payload)) else {
    fail("payload should be binary")
  }
  assert_eq(payload.to_options(), [Some(b"large")])
}
