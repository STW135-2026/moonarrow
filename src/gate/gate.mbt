///|
/// Errors raised when a contract, Arrow batch, or release policy is invalid.
pub(all) enum GateError {
  InvalidContract(String)
  InvalidBatch
  InvalidRedaction(String)
} derive(Eq, Debug)

///|
/// Rule severity controls whether a finding quarantines a row.
pub(all) enum Severity {
  Warning
  Error
} derive(Eq, Debug)

///|
/// Stable machine-readable finding codes.
pub(all) enum FindingCode {
  MissingColumn
  TypeMismatch
  NullValue
  OutOfRange
  EmptyValue
  NotAllowed
  DuplicateValue
  CrossFieldOrder
} derive(Eq, Debug)

///|
/// One data-quality finding. `row=None` denotes a dataset-level finding.
pub(all) struct Finding {
  rule_id : String
  severity : Severity
  row : Int?
  column : String?
  code : FindingCode
  message : String
} derive(Eq, Debug)

///|
/// Declarative checks supported by MoonSentinel's first release.
pub(all) enum Rule {
  RequiredColumn(String, String, @arrow.DataType, Severity)
  NotNull(String, String, Severity)
  Int32Range(String, String, Int?, Int?, Severity)
  Int64Range(String, String, Int64?, Int64?, Severity)
  Utf8NonEmpty(String, String, Severity)
  Utf8Allowed(String, String, Array[String], Severity)
  Utf8Unique(String, String, Severity)
  Int32LessOrEqual(String, String, String, Severity)
} derive(Debug)

///|
/// A release-time data contract. Rules run in declaration order and rows are
/// inspected in source order so reports are reproducible.
pub struct Contract {
  name : String
  rules : Array[Rule]
  max_findings : Int
}

///|
/// A privacy transformation applied only to rows approved for release.
pub(all) enum Redaction {
  ReplaceUtf8(String, String)
} derive(Eq, Debug)

///|
/// Result of an audit. Counts include findings omitted by `max_findings`.
pub struct AuditReport {
  contract_name : String
  source_rows : Int
  error_count_value : Int
  warning_count_value : Int
  findings_value : Array[Finding]
  truncated_value : Bool
  accepted_indices : Array[Int]
  rejected_indices : Array[Int]
}

///|
/// Release output: safe rows, quarantined rows, and Arrow-native diagnostics.
pub struct ReleaseBundle {
  report_value : AuditReport
  approved_value : @arrow.RecordBatch
  quarantine_value : @arrow.RecordBatch
  findings_value : @arrow.RecordBatch
}

///|
priv struct AuditState {
  findings : Array[Finding]
  counts : Array[Int]
  rejected : Array[Bool]
  max_findings : Int
}

///|
fn data_type_name(data_type : @arrow.DataType) -> String {
  match data_type {
    @arrow.Null => "null"
    @arrow.Boolean => "bool"
    @arrow.Int32 => "int32"
    @arrow.Int64 => "int64"
    @arrow.Float64 => "float64"
    @arrow.Utf8 => "utf8"
    @arrow.Binary => "binary"
  }
}

///|
fn severity_text(severity : Severity) -> String {
  match severity {
    Warning => "warning"
    Error => "error"
  }
}

///|
fn finding_code_text(code : FindingCode) -> String {
  match code {
    MissingColumn => "missing_column"
    TypeMismatch => "type_mismatch"
    NullValue => "null_value"
    OutOfRange => "out_of_range"
    EmptyValue => "empty_value"
    NotAllowed => "not_allowed"
    DuplicateValue => "duplicate_value"
    CrossFieldOrder => "cross_field_order"
  }
}

///|
fn rule_id(rule : Rule) -> String {
  match rule {
    RequiredColumn(id, _, _, _) => id
    NotNull(id, _, _) => id
    Int32Range(id, _, _, _, _) => id
    Int64Range(id, _, _, _, _) => id
    Utf8NonEmpty(id, _, _) => id
    Utf8Allowed(id, _, _, _) => id
    Utf8Unique(id, _, _) => id
    Int32LessOrEqual(id, _, _, _) => id
  }
}

///|
fn copy_rule(rule : Rule) -> Rule {
  match rule {
    RequiredColumn(id, column, data_type, severity) =>
      RequiredColumn(id, column, data_type, severity)
    NotNull(id, column, severity) => NotNull(id, column, severity)
    Int32Range(id, column, minimum, maximum, severity) =>
      Int32Range(id, column, minimum, maximum, severity)
    Int64Range(id, column, minimum, maximum, severity) =>
      Int64Range(id, column, minimum, maximum, severity)
    Utf8NonEmpty(id, column, severity) => Utf8NonEmpty(id, column, severity)
    Utf8Allowed(id, column, allowed, severity) =>
      Utf8Allowed(id, column, allowed.copy(), severity)
    Utf8Unique(id, column, severity) => Utf8Unique(id, column, severity)
    Int32LessOrEqual(id, left, right, severity) =>
      Int32LessOrEqual(id, left, right, severity)
  }
}

///|
fn invalid_rule(rule : Rule) -> String? {
  let id = rule_id(rule)
  if id == "" {
    return Some("rule id must not be empty")
  }
  match rule {
    RequiredColumn(_, column, _, _)
    | NotNull(_, column, _)
    | Utf8NonEmpty(_, column, _)
    | Utf8Unique(_, column, _) =>
      if column == "" {
        Some("column name must not be empty")
      } else {
        None
      }
    Int32Range(_, column, minimum, maximum, _) => {
      if column == "" {
        return Some("column name must not be empty")
      }
      match (minimum, maximum) {
        (Some(low), Some(high)) if low > high =>
          Some("int32 range minimum exceeds maximum")
        _ => None
      }
    }
    Int64Range(_, column, minimum, maximum, _) => {
      if column == "" {
        return Some("column name must not be empty")
      }
      match (minimum, maximum) {
        (Some(low), Some(high)) if low > high =>
          Some("int64 range minimum exceeds maximum")
        _ => None
      }
    }
    Utf8Allowed(_, column, allowed, _) => {
      if column == "" {
        return Some("column name must not be empty")
      }
      if allowed.is_empty() {
        return Some("allowed value list must not be empty")
      }
      for index in 0..<allowed.length() {
        for previous in 0..<index {
          if allowed[index] == allowed[previous] {
            return Some("allowed value list contains duplicates")
          }
        }
      }
      None
    }
    Int32LessOrEqual(_, left, right, _) =>
      if left == "" || right == "" {
        Some("cross-field rule columns must not be empty")
      } else if left == right {
        Some("cross-field rule columns must differ")
      } else {
        None
      }
  }
}

///|
pub fn Contract::new(
  name : String,
  rules : Array[Rule],
  max_findings? : Int = 100,
) -> Result[Contract, GateError] {
  if name == "" {
    return Err(InvalidContract("contract name must not be empty"))
  }
  if rules.is_empty() {
    return Err(InvalidContract("contract must contain at least one rule"))
  }
  if max_findings < 1 {
    return Err(InvalidContract("max_findings must be positive"))
  }
  for index in 0..<rules.length() {
    match invalid_rule(rules[index]) {
      Some(message) => return Err(InvalidContract(message))
      None => ()
    }
    for previous in 0..<index {
      if rule_id(rules[index]) == rule_id(rules[previous]) {
        return Err(
          InvalidContract("duplicate rule id: " + rule_id(rules[index])),
        )
      }
    }
  }
  Ok({ name, rules: rules.map(rule => copy_rule(rule)), max_findings, })
}

///|
pub fn Contract::name(self : Contract) -> String {
  self.name
}

///|
fn field_index(schema : @arrow.Schema, name : String) -> Int? {
  for index in 0..<schema.fields.length() {
    if schema.fields[index].name == name {
      return Some(index)
    }
  }
  None
}

///|
fn record_finding(state : AuditState, finding : Finding) -> Unit {
  match finding.severity {
    Error => {
      state.counts[0] = state.counts[0] + 1
      match finding.row {
        Some(row) => state.rejected[row] = true
        None =>
          for row in 0..<state.rejected.length() {
            state.rejected[row] = true
          }
      }
    }
    Warning => state.counts[1] = state.counts[1] + 1
  }
  if state.findings.length() < state.max_findings {
    state.findings.push(finding)
  }
}

///|
fn resolve_column(
  batch : @arrow.RecordBatch,
  state : AuditState,
  id : String,
  severity : Severity,
  column : String,
  expected : @arrow.DataType?,
) -> Int? {
  guard field_index(batch.schema, column) is Some(index) else {
    record_finding(state, {
      rule_id: id,
      severity,
      row: None,
      column: Some(column),
      code: MissingColumn,
      message: "required column '" + column + "' is missing",
    })
    return None
  }
  match expected {
    Some(data_type) if batch.columns[index].data_type() != data_type => {
      record_finding(state, {
        rule_id: id,
        severity,
        row: None,
        column: Some(column),
        code: TypeMismatch,
        message: "column '" +
        column +
        "' expected " +
        data_type_name(data_type) +
        " but found " +
        data_type_name(batch.columns[index].data_type()),
      })
      None
    }
    _ => Some(index)
  }
}

///|
fn column_has_value(column : @arrow.Column, row : Int) -> Bool {
  match column {
    @arrow.Nulls(_) => false
    @arrow.Booleans(values) => values[row] is Some(_)
    @arrow.Int32s(values) => values[row] is Some(_)
    @arrow.Int64s(values) => values[row] is Some(_)
    @arrow.Float64s(values) => values[row] is Some(_)
    @arrow.Strings(values) => values[row] is Some(_)
    @arrow.Binaries(values) => values[row] is Some(_)
  }
}

///|
fn row_finding(
  state : AuditState,
  id : String,
  severity : Severity,
  row : Int,
  column : String,
  code : FindingCode,
  message : String,
) -> Unit {
  record_finding(state, {
    rule_id: id,
    severity,
    row: Some(row),
    column: Some(column),
    code,
    message,
  })
}

///|
fn value_is_allowed(value : String, allowed : Array[String]) -> Bool {
  for candidate in allowed {
    if value == candidate {
      return true
    }
  }
  false
}

///|
fn apply_rule(
  batch : @arrow.RecordBatch,
  state : AuditState,
  rule : Rule,
) -> Unit {
  match rule {
    RequiredColumn(id, column, expected, severity) =>
      ignore(resolve_column(batch, state, id, severity, column, Some(expected)))
    NotNull(id, column, severity) =>
      match resolve_column(batch, state, id, severity, column, None) {
        None => ()
        Some(index) =>
          for row in 0..<batch.num_rows {
            if !column_has_value(batch.columns[index], row) {
              row_finding(
                state,
                id,
                severity,
                row,
                column,
                NullValue,
                "column '" + column + "' is null",
              )
            }
          }
      }
    Int32Range(id, column, minimum, maximum, severity) =>
      match
        resolve_column(batch, state, id, severity, column, Some(@arrow.Int32)) {
        None => ()
        Some(index) =>
          match batch.columns[index] {
            @arrow.Int32s(values) =>
              for row in 0..<values.length() {
                match values[row] {
                  None => ()
                  Some(value) => {
                    let below = match minimum {
                      Some(low) => value < low
                      None => false
                    }
                    let above = match maximum {
                      Some(high) => value > high
                      None => false
                    }
                    if below || above {
                      row_finding(
                        state,
                        id,
                        severity,
                        row,
                        column,
                        OutOfRange,
                        "column '" +
                        column +
                        "' is outside the configured int32 range",
                      )
                    }
                  }
                }
              }
            _ => ()
          }
      }
    Int64Range(id, column, minimum, maximum, severity) =>
      match
        resolve_column(batch, state, id, severity, column, Some(@arrow.Int64)) {
        None => ()
        Some(index) =>
          match batch.columns[index] {
            @arrow.Int64s(values) =>
              for row in 0..<values.length() {
                match values[row] {
                  None => ()
                  Some(value) => {
                    let below = match minimum {
                      Some(low) => value < low
                      None => false
                    }
                    let above = match maximum {
                      Some(high) => value > high
                      None => false
                    }
                    if below || above {
                      row_finding(
                        state,
                        id,
                        severity,
                        row,
                        column,
                        OutOfRange,
                        "column '" +
                        column +
                        "' is outside the configured int64 range",
                      )
                    }
                  }
                }
              }
            _ => ()
          }
      }
    Utf8NonEmpty(id, column, severity) =>
      match
        resolve_column(batch, state, id, severity, column, Some(@arrow.Utf8)) {
        None => ()
        Some(index) =>
          match batch.columns[index] {
            @arrow.Strings(values) =>
              for row in 0..<values.length() {
                if values[row] == Some("") {
                  row_finding(
                    state,
                    id,
                    severity,
                    row,
                    column,
                    EmptyValue,
                    "column '" + column + "' is empty",
                  )
                }
              }
            _ => ()
          }
      }
    Utf8Allowed(id, column, allowed, severity) =>
      match
        resolve_column(batch, state, id, severity, column, Some(@arrow.Utf8)) {
        None => ()
        Some(index) =>
          match batch.columns[index] {
            @arrow.Strings(values) =>
              for row in 0..<values.length() {
                match values[row] {
                  Some(value) if !value_is_allowed(value, allowed) =>
                    row_finding(
                      state,
                      id,
                      severity,
                      row,
                      column,
                      NotAllowed,
                      "column '" +
                      column +
                      "' contains a value outside the allowlist",
                    )
                  _ => ()
                }
              }
            _ => ()
          }
      }
    Utf8Unique(id, column, severity) =>
      match
        resolve_column(batch, state, id, severity, column, Some(@arrow.Utf8)) {
        None => ()
        Some(index) =>
          match batch.columns[index] {
            @arrow.Strings(values) =>
              for row in 0..<values.length() {
                match values[row] {
                  None => ()
                  Some(value) => {
                    let mut duplicated = false
                    for other in 0..<values.length() {
                      if other != row && values[other] == Some(value) {
                        duplicated = true
                        break
                      }
                    }
                    if duplicated {
                      row_finding(
                        state,
                        id,
                        severity,
                        row,
                        column,
                        DuplicateValue,
                        "column '" + column + "' contains a duplicate value",
                      )
                    }
                  }
                }
              }
            _ => ()
          }
      }
    Int32LessOrEqual(id, left, right, severity) => {
      let left_index = resolve_column(
        batch,
        state,
        id,
        severity,
        left,
        Some(@arrow.Int32),
      )
      let right_index = resolve_column(
        batch,
        state,
        id,
        severity,
        right,
        Some(@arrow.Int32),
      )
      match (left_index, right_index) {
        (Some(a), Some(b)) =>
          match (batch.columns[a], batch.columns[b]) {
            (@arrow.Int32s(left_values), @arrow.Int32s(right_values)) =>
              for row in 0..<batch.num_rows {
                match (left_values[row], right_values[row]) {
                  (Some(left_value), Some(right_value)) if left_value >
                    right_value =>
                    row_finding(
                      state,
                      id,
                      severity,
                      row,
                      left + "," + right,
                      CrossFieldOrder,
                      "column '" +
                      left +
                      "' must be less than or equal to '" +
                      right +
                      "'",
                    )
                  _ => ()
                }
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
}

///|
fn validate_batch(batch : @arrow.RecordBatch) -> Result[Unit, GateError] {
  try {
    batch.validate()
    Ok(())
  } catch {
    _ => Err(InvalidBatch)
  }
}

///|
fn validated_batch(
  schema : @arrow.Schema,
  columns : Array[@arrow.Column],
) -> Result[@arrow.RecordBatch, GateError] {
  Ok(@arrow.RecordBatch::new(schema, columns)) catch {
    _ => Err(InvalidBatch)
  }
}

///|
fn take_column(column : @arrow.Column, indices : Array[Int]) -> @arrow.Column {
  match column {
    @arrow.Nulls(_) => @arrow.Nulls(indices.length())
    @arrow.Booleans(values) =>
      @arrow.Booleans(indices.map(index => values[index]))
    @arrow.Int32s(values) => @arrow.Int32s(indices.map(index => values[index]))
    @arrow.Int64s(values) => @arrow.Int64s(indices.map(index => values[index]))
    @arrow.Float64s(values) =>
      @arrow.Float64s(indices.map(index => values[index]))
    @arrow.Strings(values) =>
      @arrow.Strings(indices.map(index => values[index]))
    @arrow.Binaries(values) =>
      @arrow.Binaries(indices.map(index => values[index]))
  }
}

///|
fn take_batch(
  batch : @arrow.RecordBatch,
  indices : Array[Int],
) -> Result[@arrow.RecordBatch, GateError] {
  validated_batch(
    batch.schema,
    batch.columns.map(column => take_column(column, indices)),
  )
}

///|
pub fn Contract::audit(
  self : Contract,
  batch : @arrow.RecordBatch,
) -> Result[AuditReport, GateError] {
  match validate_batch(batch) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let state : AuditState = {
    findings: [],
    counts: [0, 0],
    rejected: Array::make(batch.num_rows, false),
    max_findings: self.max_findings,
  }
  for rule in self.rules {
    apply_rule(batch, state, rule)
  }
  let accepted_indices : Array[Int] = []
  let rejected_indices : Array[Int] = []
  for row in 0..<batch.num_rows {
    if state.rejected[row] {
      rejected_indices.push(row)
    } else {
      accepted_indices.push(row)
    }
  }
  Ok({
    contract_name: self.name,
    source_rows: batch.num_rows,
    error_count_value: state.counts[0],
    warning_count_value: state.counts[1],
    findings_value: state.findings,
    truncated_value: state.counts[0] + state.counts[1] > state.findings.length(),
    accepted_indices,
    rejected_indices,
  })
}

///|
pub fn AuditReport::passed(self : AuditReport) -> Bool {
  self.error_count_value == 0
}

///|
pub fn AuditReport::source_row_count(self : AuditReport) -> Int {
  self.source_rows
}

///|
pub fn AuditReport::accepted_row_count(self : AuditReport) -> Int {
  self.accepted_indices.length()
}

///|
pub fn AuditReport::rejected_row_count(self : AuditReport) -> Int {
  self.rejected_indices.length()
}

///|
pub fn AuditReport::error_count(self : AuditReport) -> Int {
  self.error_count_value
}

///|
pub fn AuditReport::warning_count(self : AuditReport) -> Int {
  self.warning_count_value
}

///|
pub fn AuditReport::issue_count(self : AuditReport) -> Int {
  self.error_count_value + self.warning_count_value
}

///|
pub fn AuditReport::findings(self : AuditReport) -> Array[Finding] {
  self.findings_value.copy()
}

///|
pub fn AuditReport::truncated(self : AuditReport) -> Bool {
  self.truncated_value
}

///|
pub fn AuditReport::summary(self : AuditReport) -> String {
  let status = if self.passed() { "PASS" } else { "FAIL" }
  self.contract_name +
  ": " +
  status +
  "; rows=" +
  self.source_rows.to_string() +
  "; accepted=" +
  self.accepted_row_count().to_string() +
  "; quarantined=" +
  self.rejected_row_count().to_string() +
  "; errors=" +
  self.error_count_value.to_string() +
  "; warnings=" +
  self.warning_count_value.to_string() +
  "; findings_shown=" +
  self.findings_value.length().to_string() +
  "; truncated=" +
  self.truncated_value.to_string()
}

///|
pub fn AuditReport::findings_batch(
  self : AuditReport,
) -> Result[@arrow.RecordBatch, GateError] {
  let schema = @arrow.Schema::new([
    @arrow.Field::new("rule_id", @arrow.Utf8, nullable=false),
    @arrow.Field::new("severity", @arrow.Utf8, nullable=false),
    @arrow.Field::new("row", @arrow.Int32),
    @arrow.Field::new("column", @arrow.Utf8),
    @arrow.Field::new("code", @arrow.Utf8, nullable=false),
    @arrow.Field::new("message", @arrow.Utf8, nullable=false),
  ])
  validated_batch(schema, [
    @arrow.Strings(self.findings_value.map(finding => Some(finding.rule_id))),
    @arrow.Strings(
      self.findings_value.map(finding => Some(severity_text(finding.severity))),
    ),
    @arrow.Int32s(self.findings_value.map(finding => finding.row)),
    @arrow.Strings(self.findings_value.map(finding => finding.column)),
    @arrow.Strings(
      self.findings_value.map(finding => Some(finding_code_text(finding.code))),
    ),
    @arrow.Strings(self.findings_value.map(finding => Some(finding.message))),
  ])
}

///|
fn apply_redactions(
  batch : @arrow.RecordBatch,
  redactions : Array[Redaction],
) -> Result[@arrow.RecordBatch, GateError] {
  let columns = batch.columns.copy()
  let seen : Array[String] = []
  for redaction in redactions {
    match redaction {
      ReplaceUtf8(column, replacement) => {
        for previous in seen {
          if previous == column {
            return Err(
              InvalidRedaction("duplicate redaction column: " + column),
            )
          }
        }
        seen.push(column)
        guard field_index(batch.schema, column) is Some(index) else {
          return Err(InvalidRedaction("redaction column is missing: " + column))
        }
        match columns[index] {
          @arrow.Strings(values) =>
            columns[index] = @arrow.Strings(
              values.map(value => value.map(_ => replacement)),
            )
          _ =>
            return Err(
              InvalidRedaction("redaction column is not utf8: " + column),
            )
        }
      }
    }
  }
  validated_batch(batch.schema, columns)
}

///|
pub fn Contract::release(
  self : Contract,
  batch : @arrow.RecordBatch,
  redactions? : Array[Redaction] = [],
) -> Result[ReleaseBundle, GateError] {
  let report = match self.audit(batch) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let approved = match take_batch(batch, report.accepted_indices) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let safe = match apply_redactions(approved, redactions) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let quarantine = match take_batch(batch, report.rejected_indices) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let findings = match report.findings_batch() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    report_value: report,
    approved_value: safe,
    quarantine_value: quarantine,
    findings_value: findings,
  })
}

///|
pub fn ReleaseBundle::report(self : ReleaseBundle) -> AuditReport {
  self.report_value
}

///|
pub fn ReleaseBundle::approved(self : ReleaseBundle) -> @arrow.RecordBatch {
  self.approved_value
}

///|
pub fn ReleaseBundle::quarantine(self : ReleaseBundle) -> @arrow.RecordBatch {
  self.quarantine_value
}

///|
pub fn ReleaseBundle::findings(self : ReleaseBundle) -> @arrow.RecordBatch {
  self.findings_value
}
