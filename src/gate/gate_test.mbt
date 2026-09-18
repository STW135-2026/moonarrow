///|
fn customer_batch() -> @arrow.RecordBatch {
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
fn customer_contract(max_findings? : Int = 100) -> Contract {
  Contract::new(
    "customer-export-v1",
    [
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
    ],
    max_findings~,
  ).unwrap()
}

///|
test "release quarantines bad rows and masks approved rows" {
  let bundle = customer_contract()
    .release(customer_batch(), redactions=[
      @gate.ReplaceUtf8("email", "[REDACTED]"),
    ])
    .unwrap()
  let report = bundle.report()
  assert_false(report.passed())
  assert_eq(report.error_count(), 7)
  assert_eq(report.warning_count(), 1)
  assert_eq(report.accepted_row_count(), 1)
  assert_eq(report.rejected_row_count(), 3)
  assert_eq(bundle.approved().num_rows, 1)
  assert_eq(bundle.quarantine().num_rows, 3)
  assert_eq(bundle.findings().num_rows, 8)
  assert_true(
    bundle.approved().columns[5] is @arrow.Strings([Some("[REDACTED]")]),
  )
  assert_true(
    bundle.quarantine().columns[5]
    is @arrow.Strings([Some("two@example.com"), None, Some("four@example.com")]),
  )
}

///|
test "bounded findings preserve exact counts" {
  let report = customer_contract(max_findings=2)
    .audit(customer_batch())
    .unwrap()
  assert_eq(report.issue_count(), 8)
  assert_eq(report.findings().length(), 2)
  assert_true(report.truncated())
  assert_true(report.summary().contains("findings_shown=2"))
}

///|
test "findings are Arrow-native and survive IPC" {
  let findings = customer_contract()
    .audit(customer_batch())
    .unwrap()
    .findings_batch()
    .unwrap()
  let bytes = try! @arrow.write_stream(findings.schema, [findings])
  let restored = try! @arrow.read_stream(bytes)
  assert_eq(restored.batches.length(), 1)
  assert_eq(restored.batches[0].num_rows, 8)
  assert_true(
    restored.batches[0].columns[4]
    is @arrow.Strings(
      [
        Some("duplicate_value"),
        Some("duplicate_value"),
        Some("null_value"),
        Some("out_of_range"),
        Some("not_allowed"),
        Some("cross_field_order"),
        Some("cross_field_order"),
        Some("null_value"),
      ]
    ),
  )
}

///|
test "dataset-level schema error rejects every row" {
  let contract = Contract::new("schema-check", [
    @gate.RequiredColumn("schema.email", "email", @arrow.Utf8, @gate.Error),
  ]).unwrap()
  let schema = @arrow.Schema::new([
    @arrow.Field::new("email", @arrow.Int32, nullable=false),
  ])
  let batch = try! @arrow.RecordBatch::new(schema, [
    @arrow.Int32s([Some(1), Some(2)]),
  ])
  let report = contract.audit(batch).unwrap()
  assert_eq(report.error_count(), 1)
  assert_eq(report.accepted_row_count(), 0)
  assert_eq(report.rejected_row_count(), 2)
  assert_true(report.findings()[0].code is @gate.TypeMismatch)
}

///|
test "warnings never quarantine rows" {
  let contract = Contract::new("warning-only", [
    @gate.NotNull("email.recommended", "email", @gate.Warning),
  ]).unwrap()
  let schema = @arrow.Schema::new([@arrow.Field::new("email", @arrow.Utf8)])
  let batch = try! @arrow.RecordBatch::new(schema, [
    @arrow.Strings([Some("a@example.com"), None]),
  ])
  let report = contract.audit(batch).unwrap()
  assert_true(report.passed())
  assert_eq(report.warning_count(), 1)
  assert_eq(report.accepted_row_count(), 2)
}

///|
test "invalid contracts and redactions return structured errors" {
  assert_true(
    Contract::new("", [@gate.NotNull("id", "customer_id", @gate.Error)])
    is Err(@gate.InvalidContract(_)),
  )
  assert_true(
    Contract::new("bad", [
      @gate.Int32Range("age", "age", Some(10), Some(1), @gate.Error),
    ])
    is Err(@gate.InvalidContract(_)),
  )
  assert_true(
    Contract::new("duplicate", [
      @gate.NotNull("same", "a", @gate.Error),
      @gate.NotNull("same", "b", @gate.Error),
    ])
    is Err(@gate.InvalidContract(_)),
  )
  assert_true(
    customer_contract().release(customer_batch(), redactions=[
      @gate.ReplaceUtf8("age", "hidden"),
    ])
    is Err(@gate.InvalidRedaction(_)),
  )
}

///|
test "mutated invalid Arrow batches are rejected" {
  let values : Array[String?] = [Some("c-1")]
  let schema = @arrow.Schema::new([
    @arrow.Field::new("customer_id", @arrow.Utf8, nullable=false),
  ])
  let batch = try! @arrow.RecordBatch::new(schema, [@arrow.Strings(values)])
  values[0] = None
  let contract = Contract::new("valid", [
    @gate.NotNull("id", "customer_id", @gate.Error),
  ]).unwrap()
  assert_true(contract.audit(batch) is Err(@gate.InvalidBatch))
}
