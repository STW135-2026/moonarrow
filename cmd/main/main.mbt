///|
fn option_string_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => "null"
  }
}

///|
fn option_int64_text(value : Int64?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "null"
  }
}

///|
fn main {
  let schema = @arrow.Schema::new([
    @arrow.Field::new("region", @arrow.Utf8),
    @arrow.Field::new("product", @arrow.Utf8, nullable=false),
    @arrow.Field::new("units", @arrow.Int32),
    @arrow.Field::new("revenue", @arrow.Int32),
    @arrow.Field::new("active", @arrow.Boolean),
  ])
  let source = try! @arrow.RecordBatch::new(schema, [
    @arrow.Strings([
      Some("East"),
      Some("West"),
      Some("East"),
      Some("North"),
      None,
    ]),
    @arrow.Strings([Some("A"), Some("B"), Some("C"), Some("D"), Some("E")]),
    @arrow.Int32s([Some(4), Some(2), Some(7), Some(1), Some(8)]),
    @arrow.Int32s([Some(120), Some(80), Some(200), Some(40), None]),
    @arrow.Booleans([
      Some(true),
      Some(true),
      Some(true),
      Some(false),
      Some(true),
    ]),
  ])
  let query = @query.Query::scan(source)
    .filter(
      @query.Int32GreaterThan("units", 2).and_also(@query.BoolIsTrue("active")),
    )
    .group_by_utf8_sum_int32(
      "region",
      "revenue",
      sum_alias="revenue_sum",
      count_alias="orders",
    )
    .sort_by("revenue_sum", descending=true)
    .limit(3)
  println("MoonQuery logical plan")
  println(query.explain())
  let result = query.execute().unwrap()
  println("\nResult rows: \{result.num_rows}")
  match (result.columns[0], result.columns[1], result.columns[2]) {
    (
      @arrow.Strings(regions),
      @arrow.Int64s(revenue_sums),
      @arrow.Int64s(order_counts),
    ) =>
      for row in 0..<result.num_rows {
        println(
          "  region=" +
          option_string_text(regions[row]) +
          ", revenue_sum=" +
          option_int64_text(revenue_sums[row]) +
          ", orders=" +
          option_int64_text(order_counts[row]),
        )
      }
    _ => println("unexpected result schema")
  }
  let ipc = try! @arrow.write_stream(result.schema, [result])
  let restored = try! @arrow.read_stream(ipc)
  println(
    "\nArrow IPC handoff supplied by shunge/arrow: \{ipc.length()} bytes, \{restored.batches[0].num_rows} rows",
  )
}
