///|
fn sales_batch() -> @arrow.RecordBatch {
  let schema = @arrow.Schema::new([
    @arrow.Field::new("region", @arrow.Utf8),
    @arrow.Field::new("product", @arrow.Utf8, nullable=false),
    @arrow.Field::new("units", @arrow.Int32),
    @arrow.Field::new("revenue", @arrow.Int32),
    @arrow.Field::new("active", @arrow.Boolean),
  ])
  try! @arrow.RecordBatch::new(schema, [
    @arrow.Strings([Some("East"), Some("West"), Some("East"), None]),
    @arrow.Strings([Some("A"), Some("B"), Some("C"), Some("D")]),
    @arrow.Int32s([Some(4), Some(2), None, Some(8)]),
    @arrow.Int32s([Some(120), Some(80), Some(200), None]),
    @arrow.Booleans([Some(true), Some(true), None, Some(false)]),
  ])
}

///|
test "lazy plan filters projects sorts and limits" {
  let query = Query::scan(sales_batch())
    .filter(
      @query.Int32GreaterThan("units", 1).and_also(@query.BoolIsTrue("active")),
    )
    .project(["product", "units"])
    .sort_by("units", descending=true)
    .limit(1)
  let result = query.execute().unwrap()
  assert_eq(result.num_rows, 1)
  assert_eq(result.schema.fields.map(field => field.name), ["product", "units"])
  assert_true(result.columns[0] is @arrow.Strings([Some("A")]))
  assert_true(result.columns[1] is @arrow.Int32s([Some(4)]))
  assert_true(query.explain().contains("Filter"))
  assert_true(query.explain().contains("Sort units DESC NULLS LAST"))
}

///|
test "filter uses three-valued null semantics" {
  let result = Query::scan(sales_batch())
    .filter(
      @query.BoolIsTrue("active").or_else(@query.Int32GreaterThan("units", 6)),
    )
    .project(["product"])
    .execute()
    .unwrap()
  assert_eq(result.num_rows, 3)
  assert_true(
    result.columns[0] is @arrow.Strings([Some("A"), Some("B"), Some("D")]),
  )
}

///|
test "group by returns nullable sum and non-null count" {
  let result = Query::scan(sales_batch())
    .group_by_utf8_sum_int32(
      "region",
      "revenue",
      sum_alias="revenue_sum",
      count_alias="rows",
    )
    .sort_by("revenue_sum", descending=true)
    .execute()
    .unwrap()
  assert_eq(result.num_rows, 3)
  assert_true(
    result.columns[0] is @arrow.Strings([Some("East"), Some("West"), None]),
  )
  assert_true(result.columns[1] is @arrow.Int64s([Some(320L), Some(80L), None]))
  assert_true(
    result.columns[2] is @arrow.Int64s([Some(2L), Some(1L), Some(1L)]),
  )
}

///|
test "inner join prefixes fields and never matches null keys" {
  let right_schema = @arrow.Schema::new([
    @arrow.Field::new("product", @arrow.Utf8),
    @arrow.Field::new("category", @arrow.Utf8, nullable=false),
  ])
  let right = try! @arrow.RecordBatch::new(right_schema, [
    @arrow.Strings([Some("A"), Some("C"), None]),
    @arrow.Strings([Some("Core"), Some("Pro"), Some("Unknown")]),
  ])
  let result = Query::scan(sales_batch())
    .inner_join(right, "product", "product")
    .execute()
    .unwrap()
  assert_eq(result.num_rows, 2)
  assert_eq(result.schema.fields[0].name, "left.region")
  assert_eq(result.schema.fields[5].name, "right.product")
  assert_true(result.columns[6] is @arrow.Strings([Some("Core"), Some("Pro")]))
}

///|
test "Arrow IPC roundtrip is supplied by shunge arrow" {
  let result = Query::scan(sales_batch())
    .filter(@query.Int32GreaterThan("units", 2))
    .project(["product", "revenue"])
    .execute()
    .unwrap()
  let bytes = try! @arrow.write_stream(result.schema, [result])
  let restored = try! @arrow.read_stream(bytes)
  assert_eq(restored.batches.length(), 1)
  assert_eq(restored.batches[0].num_rows, 2)
  assert_true(
    restored.batches[0].columns[0] is @arrow.Strings([Some("A"), Some("D")]),
  )
}

///|
test "invalid plans return structured errors" {
  assert_true(
    Query::scan(sales_batch()).project([]).execute()
    is Err(@query.EmptyProjection),
  )
  assert_true(
    Query::scan(sales_batch()).limit(-1).execute()
    is Err(@query.InvalidLimit(-1)),
  )
  assert_true(
    Query::scan(sales_batch())
    .filter(@query.Utf8Equal("units", "four"))
    .execute()
    is Err(@query.TypeMismatch("units", "utf8", "int32")),
  )
}

///|
test "descending sort keeps null and NaN after finite values" {
  let schema = @arrow.Schema::new([@arrow.Field::new("value", @arrow.Float64)])
  let nan = 0.0 / 0.0
  let batch = try! @arrow.RecordBatch::new(schema, [
    @arrow.Float64s([Some(2.0), None, Some(nan), Some(5.0)]),
  ])
  let result = Query::scan(batch)
    .sort_by("value", descending=true)
    .execute()
    .unwrap()
  guard result.columns[0] is @arrow.Float64s(values) else {
    fail("expected float64 column")
  }
  assert_eq(values[0], Some(5.0))
  assert_eq(values[1], Some(2.0))
  assert_true(values[2] is Some(value) && value != value)
  assert_eq(values[3], None)
}

///|
test "null and not semantics are explicit" {
  let result = Query::scan(sales_batch())
    .filter(@query.BoolIsTrue("active").negate())
    .project(["product"])
    .execute()
    .unwrap()
  assert_true(result.columns[0] is @arrow.Strings([Some("D")]))
}

///|
test "mutable invalid source is rejected before execution" {
  let values : Array[Int?] = [Some(1)]
  let schema = @arrow.Schema::new([
    @arrow.Field::new("id", @arrow.Int32, nullable=false),
  ])
  let batch = try! @arrow.RecordBatch::new(schema, [@arrow.Int32s(values)])
  values[0] = None
  assert_true(Query::scan(batch).execute() is Err(@query.InvalidBatch))
}

///|
test "missing and duplicate projections are rejected" {
  assert_true(
    Query::scan(sales_batch()).project(["missing"]).execute()
    is Err(@query.ColumnNotFound("missing")),
  )
  assert_true(
    Query::scan(sales_batch()).project(["region", "region"]).execute()
    is Err(@query.DuplicateColumn("region")),
  )
}
