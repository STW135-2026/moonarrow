///|
fn main {
  let schema = @types.Schema::new([
    @types.Field::new("city", @types.Utf8, nullable=false),
    @types.Field::new("temperature_c", @types.Int32),
  ]).unwrap()
  let temperatures = @array.Int32Array::from_options([
    Some(31),
    Some(19),
    None,
    Some(27),
  ])
  let cities = @array.Utf8Array::from_values([
    "Shenzhen", "Paris", "Unknown", "Tokyo",
  ])
  let batch = @record_batch.RecordBatch::new(schema, [
    @record_batch.Utf8(cities),
    @record_batch.Int32(temperatures),
  ]).unwrap()
  let frame = @dataframe.DataFrame::from_record_batch(batch)
  let filtered = frame
    .where_int32_gt("temperature_c", 25)
    .unwrap()
    .select(["city", "temperature_c"])
    .unwrap()
  println("MoonArrow DataFrame demo")
  println("rows: \{frame.row_count()}")
  println(
    "temperature sum: \{frame.sum_int32("temperature_c").unwrap().unwrap_or(0L)}",
  )
  println(
    "temperature mean: \{frame.mean_int32("temperature_c").unwrap().unwrap_or(0.0)}",
  )
  println("warm rows: \{filtered.row_count()}")
}
