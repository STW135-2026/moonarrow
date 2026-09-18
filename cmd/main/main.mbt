///|
fn source_batch() -> @arrow.RecordBatch {
  let schema = @arrow.Schema::new([
    @arrow.Field::new("customer_id", @arrow.Utf8, nullable=false),
    @arrow.Field::new("age", @arrow.Int32),
    @arrow.Field::new("min_order", @arrow.Int32),
    @arrow.Field::new("max_order", @arrow.Int32),
    @arrow.Field::new("country", @arrow.Utf8),
    @arrow.Field::new("email", @arrow.Utf8),
  ])
  try! @arrow.RecordBatch::new(schema, [
    @arrow.Strings([Some("c-1"), Some("c-2"), Some("c-2"), Some("c-4")]),
    @arrow.Int32s([Some(32), Some(-1), Some(45), None]),
    @arrow.Int32s([Some(10), Some(30), Some(90), Some(5)]),
    @arrow.Int32s([Some(100), Some(20), Some(80), Some(30)]),
    @arrow.Strings([Some("CN"), Some("US"), Some("FR"), Some("CN")]),
    @arrow.Strings([
      Some("one@example.com"),
      Some("two@example.com"),
      None,
      Some("four@example.com"),
    ]),
  ])
}

///|
fn contract() -> @gate.Contract {
  @gate.Contract::new("customer-export-v1", [
    @gate.RequiredColumn(
      "schema.customer_id",
      "customer_id",
      @arrow.Utf8,
      @gate.Error,
    ),
    @gate.NotNull("quality.customer_id.required", "customer_id", @gate.Error),
    @gate.Utf8Unique("quality.customer_id.unique", "customer_id", @gate.Error),
    @gate.NotNull("quality.age.required", "age", @gate.Error),
    @gate.Int32Range(
      "quality.age.range",
      "age",
      Some(0),
      Some(120),
      @gate.Error,
    ),
    @gate.Utf8Allowed(
      "quality.country.allowlist",
      "country",
      ["CN", "US"],
      @gate.Error,
    ),
    @gate.Int32LessOrEqual(
      "quality.order.bounds",
      "min_order",
      "max_order",
      @gate.Error,
    ),
    @gate.NotNull("quality.email.recommended", "email", @gate.Warning),
  ]).unwrap()
}

///|
fn main {
  let bundle = contract()
    .release(source_batch(), redactions=[
      @gate.ReplaceUtf8("email", "[REDACTED]"),
    ])
    .unwrap()
  println("MoonSentinel release gate")
  println(bundle.report().summary())
  println("approved rows: \{bundle.approved().num_rows}")
  println("quarantined rows: \{bundle.quarantine().num_rows}")
  println("diagnostic rows: \{bundle.findings().num_rows}")
  match bundle.approved().columns[5] {
    @arrow.Strings(values) => println("approved email: \{values[0].unwrap()}")
    _ => println("unexpected email column")
  }
  let bytes = try! @arrow.write_stream(bundle.approved().schema, [
    bundle.approved(),
  ])
  let restored = try! @arrow.read_stream(bytes)
  println(
    "Arrow IPC handoff: \{bytes.length()} bytes, \{restored.batches[0].num_rows} approved row",
  )
}
