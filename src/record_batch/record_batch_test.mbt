///|
fn sample_schema() -> @types.Schema {
  @types.Schema::new([
    @types.Field::new("city", @types.Utf8, nullable=false),
    @types.Field::new("temperature", @types.Int32),
  ]).unwrap()
}

///|
test "record batch validates and retrieves columns" {
  let batch = @record_batch.RecordBatch::new(sample_schema(), [
    @record_batch.Utf8(@array.Utf8Array::from_values(["Shenzhen", "Paris"])),
    @record_batch.Int32(@array.Int32Array::from_options([Some(31), None])),
  ])
  guard batch is Ok(batch) else { fail("batch should be valid") }
  assert_eq(batch.row_count(), 2)
  assert_eq(batch.column_count(), 2)
  assert_true(
    batch.column_by_name("temperature") is Some(@record_batch.Int32(_)),
  )
}

///|
test "record batch rejects length mismatch" {
  let batch = @record_batch.RecordBatch::new(sample_schema(), [
    @record_batch.Utf8(@array.Utf8Array::from_values(["Shenzhen", "Paris"])),
    @record_batch.Int32(@array.Int32Array::from_values([31])),
  ])
  assert_true(batch is Err(@record_batch.ColumnLengthMismatch(1, 1, 2)))
}

///|
test "record batch rejects schema type mismatch" {
  let batch = @record_batch.RecordBatch::new(sample_schema(), [
    @record_batch.Utf8(@array.Utf8Array::from_values(["Shenzhen"])),
    @record_batch.Float64(@array.Float64Array::from_values([31.0])),
  ])
  assert_true(
    batch
    is Err(@record_batch.ColumnTypeMismatch(1, @types.Float64, @types.Int32)),
  )
}

///|
test "record batch filters all columns together" {
  let batch = @record_batch.RecordBatch::new(sample_schema(), [
    @record_batch.Utf8(
      @array.Utf8Array::from_values(["Shenzhen", "Paris", "Tokyo"]),
    ),
    @record_batch.Int32(
      @array.Int32Array::from_options([Some(31), None, Some(27)]),
    ),
  ]).unwrap()
  let predicate = @array.BoolArray::from_values([true, false, true])
  guard batch.filter(predicate) is Ok(filtered) else {
    fail("filter should work")
  }
  assert_eq(filtered.row_count(), 2)
  guard filtered.column_by_name("city") is Some(@record_batch.Utf8(city)) else {
    fail("city column should exist")
  }
  assert_eq(city.to_options(), [Some("Shenzhen"), Some("Tokyo")])
}

///|
test "column slices preserve values and nulls" {
  let column = @record_batch.Int32(
    @array.Int32Array::from_options([Some(1), None, Some(3)]),
  )
  guard column.slice(1, 2) is Ok(@record_batch.Int32(sliced)) else {
    fail("slice should succeed")
  }
  assert_eq(sliced.to_options(), [None, Some(3)])
}
