///|
/// Errors reported while validating or executing a MoonQuery plan.
pub(all) enum QueryError {
  ColumnNotFound(String)
  DuplicateColumn(String)
  EmptyProjection
  InvalidLimit(Int)
  TypeMismatch(String, String, String)
  UnsupportedOperation(String)
  InvalidBatch
} derive(Eq, Debug)

///|
/// A typed predicate evaluated with SQL-style three-valued Boolean semantics.
/// A null result is treated as false by a filter, while `and`, `or`, and `not`
/// preserve nulls while the expression is evaluated.
pub(all) enum Predicate {
  BoolIsTrue(String)
  Int32Equal(String, Int)
  Int32GreaterThan(String, Int)
  Int32LessThan(String, Int)
  Int64Equal(String, Int64)
  Int64GreaterThan(String, Int64)
  Utf8Equal(String, String)
  And(Predicate, Predicate)
  Or(Predicate, Predicate)
  Not(Predicate)
} derive(Eq, Debug)

///|
pub fn Predicate::and_also(self : Predicate, other : Predicate) -> Predicate {
  And(self, other)
}

///|
pub fn Predicate::or_else(self : Predicate, other : Predicate) -> Predicate {
  Or(self, other)
}

///|
pub fn Predicate::negate(self : Predicate) -> Predicate {
  Not(self)
}

///|
fn Predicate::describe(self : Predicate) -> String {
  match self {
    BoolIsTrue(name) => "col(\"\{name}\") IS TRUE"
    Int32Equal(name, value) => "col(\"\{name}\") = \{value}"
    Int32GreaterThan(name, value) => "col(\"\{name}\") > \{value}"
    Int32LessThan(name, value) => "col(\"\{name}\") < \{value}"
    Int64Equal(name, value) => "col(\"\{name}\") = \{value}"
    Int64GreaterThan(name, value) => "col(\"\{name}\") > \{value}"
    Utf8Equal(name, value) => "col(\"\{name}\") = \"\{value}\""
    And(left, right) => "(\{left.describe()}) AND (\{right.describe()})"
    Or(left, right) => "(\{left.describe()}) OR (\{right.describe()})"
    Not(inner) => "NOT (\{inner.describe()})"
  }
}

///|
/// One logical step in a lazy query plan. IPC input and output are deliberately
/// not represented here: those responsibilities belong to `shunge/arrow`.
pub(all) enum QueryStep {
  Filter(Predicate)
  Project(Array[String])
  Limit(Int)
  Sort(String, Bool)
  GroupUtf8SumInt32(String, String, String, String)
  InnerJoin(@arrow.RecordBatch, String, String)
} derive(Debug)

///|
/// A reusable lazy plan over an Arrow record batch.
pub struct Query {
  source : @arrow.RecordBatch
  steps : Array[QueryStep]
} derive(Debug)

///|
pub fn Query::scan(source : @arrow.RecordBatch) -> Query {
  { source, steps: [], }
}

///|
fn Query::append(self : Query, step : QueryStep) -> Query {
  let steps = self.steps.copy()
  steps.push(step)
  { source: self.source, steps, }
}

///|
pub fn Query::filter(self : Query, predicate : Predicate) -> Query {
  self.append(Filter(predicate))
}

///|
pub fn Query::project(self : Query, columns : Array[String]) -> Query {
  self.append(Project(columns.copy()))
}

///|
pub fn Query::limit(self : Query, count : Int) -> Query {
  self.append(Limit(count))
}

///|
/// Sort a column with nulls last. `descending=true` reverses only non-null
/// values, so null placement remains deterministic.
pub fn Query::sort_by(
  self : Query,
  column : String,
  descending? : Bool = false,
) -> Query {
  self.append(Sort(column, descending))
}

///|
/// Group by a nullable UTF-8 column, calculate SQL-style SUM over a nullable
/// Int32 column, and include a non-null row count for every group.
pub fn Query::group_by_utf8_sum_int32(
  self : Query,
  key : String,
  value : String,
  sum_alias? : String = "sum",
  count_alias? : String = "count",
) -> Query {
  self.append(GroupUtf8SumInt32(key, value, sum_alias, count_alias))
}

///|
/// Add a deterministic inner join. Null keys never match. Result columns are
/// prefixed with `left.` and `right.` to make collisions impossible.
pub fn Query::inner_join(
  self : Query,
  right : @arrow.RecordBatch,
  left_key : String,
  right_key : String,
) -> Query {
  self.append(InnerJoin(right, left_key, right_key))
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
fn field_index(schema : @arrow.Schema, name : String) -> Int? {
  for index in 0..<schema.fields.length() {
    if schema.fields[index].name == name {
      return Some(index)
    }
  }
  None
}

///|
fn validated_batch(
  schema : @arrow.Schema,
  columns : Array[@arrow.Column],
) -> Result[@arrow.RecordBatch, QueryError] {
  Ok(@arrow.RecordBatch::new(schema, columns)) catch {
    _ => Err(InvalidBatch)
  }
}

///|
fn validate_existing_batch(
  batch : @arrow.RecordBatch,
) -> Result[Unit, QueryError] {
  try {
    batch.validate()
    Ok(())
  } catch {
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
) -> Result[@arrow.RecordBatch, QueryError] {
  let columns = batch.columns.map(column => take_column(column, indices))
  validated_batch(batch.schema, columns)
}

///|
fn and_3vl(left : Bool?, right : Bool?) -> Bool? {
  match (left, right) {
    (Some(false), _) | (_, Some(false)) => Some(false)
    (Some(true), Some(true)) => Some(true)
    _ => None
  }
}

///|
fn or_3vl(left : Bool?, right : Bool?) -> Bool? {
  match (left, right) {
    (Some(true), _) | (_, Some(true)) => Some(true)
    (Some(false), Some(false)) => Some(false)
    _ => None
  }
}

///|
fn evaluate_predicate(
  batch : @arrow.RecordBatch,
  predicate : Predicate,
  row : Int,
) -> Result[Bool?, QueryError] {
  match predicate {
    And(left, right) =>
      match evaluate_predicate(batch, left, row) {
        Err(error) => Err(error)
        Ok(left_value) =>
          evaluate_predicate(batch, right, row).map(right_value => {
            and_3vl(left_value, right_value)
          })
      }
    Or(left, right) =>
      match evaluate_predicate(batch, left, row) {
        Err(error) => Err(error)
        Ok(left_value) =>
          evaluate_predicate(batch, right, row).map(right_value => {
            or_3vl(left_value, right_value)
          })
      }
    Not(inner) =>
      evaluate_predicate(batch, inner, row).map(value => value.map(v => !v))
    BoolIsTrue(name) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Booleans(values) => Ok(values[row])
        column =>
          Err(TypeMismatch(name, "bool", data_type_name(column.data_type())))
      }
    }
    Int32Equal(name, expected) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Int32s(values) => Ok(values[row].map(value => value == expected))
        column =>
          Err(TypeMismatch(name, "int32", data_type_name(column.data_type())))
      }
    }
    Int32GreaterThan(name, expected) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Int32s(values) => Ok(values[row].map(value => value > expected))
        column =>
          Err(TypeMismatch(name, "int32", data_type_name(column.data_type())))
      }
    }
    Int32LessThan(name, expected) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Int32s(values) => Ok(values[row].map(value => value < expected))
        column =>
          Err(TypeMismatch(name, "int32", data_type_name(column.data_type())))
      }
    }
    Int64Equal(name, expected) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Int64s(values) => Ok(values[row].map(value => value == expected))
        column =>
          Err(TypeMismatch(name, "int64", data_type_name(column.data_type())))
      }
    }
    Int64GreaterThan(name, expected) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Int64s(values) => Ok(values[row].map(value => value > expected))
        column =>
          Err(TypeMismatch(name, "int64", data_type_name(column.data_type())))
      }
    }
    Utf8Equal(name, expected) => {
      guard field_index(batch.schema, name) is Some(index) else {
        return Err(ColumnNotFound(name))
      }
      match batch.columns[index] {
        @arrow.Strings(values) =>
          Ok(values[row].map(value => value == expected))
        column =>
          Err(TypeMismatch(name, "utf8", data_type_name(column.data_type())))
      }
    }
  }
}

///|
fn filter_batch(
  batch : @arrow.RecordBatch,
  predicate : Predicate,
) -> Result[@arrow.RecordBatch, QueryError] {
  let indices : Array[Int] = []
  for row in 0..<batch.num_rows {
    match evaluate_predicate(batch, predicate, row) {
      Err(error) => return Err(error)
      Ok(Some(true)) => indices.push(row)
      Ok(Some(false)) | Ok(None) => ()
    }
  }
  take_batch(batch, indices)
}

///|
fn project_batch(
  batch : @arrow.RecordBatch,
  names : Array[String],
) -> Result[@arrow.RecordBatch, QueryError] {
  if names.is_empty() {
    return Err(EmptyProjection)
  }
  let fields : Array[@arrow.Field] = []
  let columns : Array[@arrow.Column] = []
  for position in 0..<names.length() {
    let name = names[position]
    for previous in 0..<position {
      if names[previous] == name {
        return Err(DuplicateColumn(name))
      }
    }
    guard field_index(batch.schema, name) is Some(index) else {
      return Err(ColumnNotFound(name))
    }
    fields.push(batch.schema.fields[index])
    columns.push(batch.columns[index])
  }
  let schema = @arrow.Schema::new(fields, metadata=batch.schema.metadata.copy())
  validated_batch(schema, columns)
}

///|
fn limit_batch(
  batch : @arrow.RecordBatch,
  count : Int,
) -> Result[@arrow.RecordBatch, QueryError] {
  if count < 0 {
    return Err(InvalidLimit(count))
  }
  let length = if count < batch.num_rows { count } else { batch.num_rows }
  take_batch(batch, Array::makei(length, index => index))
}

///|
fn compare_present_int(left : Int, right : Int, descending : Bool) -> Int {
  let value = if left < right { -1 } else if left > right { 1 } else { 0 }
  if descending {
    -value
  } else {
    value
  }
}

///|
fn compare_present_int64(left : Int64, right : Int64, descending : Bool) -> Int {
  let value = if left < right { -1 } else if left > right { 1 } else { 0 }
  if descending {
    -value
  } else {
    value
  }
}

///|
fn compare_present_double(
  left : Double,
  right : Double,
  descending : Bool,
) -> Int {
  let left_nan = left != left
  let right_nan = right != right
  if left_nan {
    if right_nan {
      0
    } else {
      1
    }
  } else if right_nan {
    -1
  } else {
    let value = if left < right { -1 } else if left > right { 1 } else { 0 }
    if descending {
      -value
    } else {
      value
    }
  }
}

///|
fn compare_present_bool(left : Bool, right : Bool, descending : Bool) -> Int {
  let value = if left == right { 0 } else if left { 1 } else { -1 }
  if descending {
    -value
  } else {
    value
  }
}

///|
fn compare_present_string(
  left : String,
  right : String,
  descending : Bool,
) -> Int {
  let value = left.compare(right)
  if descending {
    -value
  } else {
    value
  }
}

///|
fn compare_rows(
  column : @arrow.Column,
  left : Int,
  right : Int,
  descending : Bool,
) -> Result[Int, QueryError] {
  match column {
    @arrow.Nulls(_) => Ok(0)
    @arrow.Int32s(values) =>
      match (values[left], values[right]) {
        (None, None) => Ok(0)
        (None, Some(_)) => Ok(1)
        (Some(_), None) => Ok(-1)
        (Some(a), Some(b)) => Ok(compare_present_int(a, b, descending))
      }
    @arrow.Int64s(values) =>
      match (values[left], values[right]) {
        (None, None) => Ok(0)
        (None, Some(_)) => Ok(1)
        (Some(_), None) => Ok(-1)
        (Some(a), Some(b)) => Ok(compare_present_int64(a, b, descending))
      }
    @arrow.Float64s(values) =>
      match (values[left], values[right]) {
        (None, None) => Ok(0)
        (None, Some(_)) => Ok(1)
        (Some(_), None) => Ok(-1)
        (Some(a), Some(b)) => Ok(compare_present_double(a, b, descending))
      }
    @arrow.Booleans(values) =>
      match (values[left], values[right]) {
        (None, None) => Ok(0)
        (None, Some(_)) => Ok(1)
        (Some(_), None) => Ok(-1)
        (Some(a), Some(b)) => Ok(compare_present_bool(a, b, descending))
      }
    @arrow.Strings(values) =>
      match (values[left], values[right]) {
        (None, None) => Ok(0)
        (None, Some(_)) => Ok(1)
        (Some(_), None) => Ok(-1)
        (Some(a), Some(b)) => Ok(compare_present_string(a, b, descending))
      }
    @arrow.Binaries(_) =>
      Err(UnsupportedOperation("sorting binary columns is not supported"))
  }
}

///|
fn sort_batch(
  batch : @arrow.RecordBatch,
  name : String,
  descending : Bool,
) -> Result[@arrow.RecordBatch, QueryError] {
  guard field_index(batch.schema, name) is Some(column_index) else {
    return Err(ColumnNotFound(name))
  }
  let column = batch.columns[column_index]
  let indices = Array::makei(batch.num_rows, index => index)
  for index in 1..<indices.length() {
    let current = indices[index]
    let mut position = index
    while position > 0 {
      match compare_rows(column, current, indices[position - 1], descending) {
        Err(error) => return Err(error)
        Ok(order) =>
          if order < 0 {
            indices[position] = indices[position - 1]
            position = position - 1
          } else {
            break
          }
      }
    }
    indices[position] = current
  }
  take_batch(batch, indices)
}

///|
fn group_utf8_sum_int32(
  batch : @arrow.RecordBatch,
  key_name : String,
  value_name : String,
  sum_alias : String,
  count_alias : String,
) -> Result[@arrow.RecordBatch, QueryError] {
  if key_name == sum_alias {
    return Err(DuplicateColumn(sum_alias))
  }
  if key_name == count_alias || sum_alias == count_alias {
    return Err(DuplicateColumn(count_alias))
  }
  guard field_index(batch.schema, key_name) is Some(key_index) else {
    return Err(ColumnNotFound(key_name))
  }
  guard field_index(batch.schema, value_name) is Some(value_index) else {
    return Err(ColumnNotFound(value_name))
  }
  guard batch.columns[key_index] is @arrow.Strings(key_values) else {
    return Err(
      TypeMismatch(
        key_name,
        "utf8",
        data_type_name(batch.columns[key_index].data_type()),
      ),
    )
  }
  guard batch.columns[value_index] is @arrow.Int32s(values) else {
    return Err(
      TypeMismatch(
        value_name,
        "int32",
        data_type_name(batch.columns[value_index].data_type()),
      ),
    )
  }
  let keys : Array[String?] = []
  let sums : Array[Int64] = []
  let has_sum : Array[Bool] = []
  let counts : Array[Int64] = []
  for row in 0..<batch.num_rows {
    let key = key_values[row]
    let mut group = -1
    for index in 0..<keys.length() {
      if keys[index] == key {
        group = index
        break
      }
    }
    if group < 0 {
      keys.push(key)
      sums.push(0L)
      has_sum.push(false)
      counts.push(0L)
      group = keys.length() - 1
    }
    counts[group] = counts[group] + 1L
    match values[row] {
      None => ()
      Some(value) => {
        sums[group] = sums[group] + value.to_int64()
        has_sum[group] = true
      }
    }
  }
  let nullable_sums = Array::makei(sums.length(), index => {
    if has_sum[index] {
      Some(sums[index])
    } else {
      None
    }
  })
  let count_values = counts.map(value => Some(value))
  let schema = @arrow.Schema::new([
    @arrow.Field::new(key_name, @arrow.Utf8, nullable=true),
    @arrow.Field::new(sum_alias, @arrow.Int64, nullable=true),
    @arrow.Field::new(count_alias, @arrow.Int64, nullable=false),
  ])
  validated_batch(schema, [
    @arrow.Strings(keys),
    @arrow.Int64s(nullable_sums),
    @arrow.Int64s(count_values),
  ])
}

///|
fn join_keys_equal(
  left : @arrow.Column,
  left_row : Int,
  right : @arrow.Column,
  right_row : Int,
) -> Result[Bool, QueryError] {
  match (left, right) {
    (@arrow.Booleans(a), @arrow.Booleans(b)) =>
      match (a[left_row], b[right_row]) {
        (Some(x), Some(y)) => Ok(x == y)
        _ => Ok(false)
      }
    (@arrow.Int32s(a), @arrow.Int32s(b)) =>
      match (a[left_row], b[right_row]) {
        (Some(x), Some(y)) => Ok(x == y)
        _ => Ok(false)
      }
    (@arrow.Int64s(a), @arrow.Int64s(b)) =>
      match (a[left_row], b[right_row]) {
        (Some(x), Some(y)) => Ok(x == y)
        _ => Ok(false)
      }
    (@arrow.Strings(a), @arrow.Strings(b)) =>
      match (a[left_row], b[right_row]) {
        (Some(x), Some(y)) => Ok(x == y)
        _ => Ok(false)
      }
    (@arrow.Float64s(_), @arrow.Float64s(_)) =>
      Err(UnsupportedOperation("joining on float64 keys is not supported"))
    (@arrow.Binaries(_), @arrow.Binaries(_)) =>
      Err(UnsupportedOperation("joining on binary keys is not supported"))
    (@arrow.Nulls(_), @arrow.Nulls(_)) => Ok(false)
    _ =>
      Err(
        TypeMismatch(
          "join key",
          data_type_name(left.data_type()),
          data_type_name(right.data_type()),
        ),
      )
  }
}

///|
fn prefixed_fields(
  schema : @arrow.Schema,
  prefix : String,
) -> Array[@arrow.Field] {
  schema.fields.map(field => {
    @arrow.Field::new(
      prefix + field.name,
      field.data_type,
      nullable=field.nullable,
      metadata=field.metadata.copy(),
    )
  })
}

///|
fn inner_join_batch(
  left : @arrow.RecordBatch,
  right : @arrow.RecordBatch,
  left_key : String,
  right_key : String,
) -> Result[@arrow.RecordBatch, QueryError] {
  match validate_existing_batch(right) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  guard field_index(left.schema, left_key) is Some(left_index) else {
    return Err(ColumnNotFound(left_key))
  }
  guard field_index(right.schema, right_key) is Some(right_index) else {
    return Err(ColumnNotFound(right_key))
  }
  let left_rows : Array[Int] = []
  let right_rows : Array[Int] = []
  for left_row in 0..<left.num_rows {
    for right_row in 0..<right.num_rows {
      match
        join_keys_equal(
          left.columns[left_index],
          left_row,
          right.columns[right_index],
          right_row,
        ) {
        Err(error) => return Err(error)
        Ok(true) => {
          left_rows.push(left_row)
          right_rows.push(right_row)
        }
        Ok(false) => ()
      }
    }
  }
  let fields = prefixed_fields(left.schema, "left.")
  for field in prefixed_fields(right.schema, "right.") {
    fields.push(field)
  }
  let columns = left.columns.map(column => take_column(column, left_rows))
  for column in right.columns {
    columns.push(take_column(column, right_rows))
  }
  validated_batch(@arrow.Schema::new(fields), columns)
}

///|
/// Return a stable, human-readable logical plan for demos and diagnostics.
pub fn Query::explain(self : Query) -> String {
  let mut text = "0: Scan ArrowRecordBatch(rows=\{self.source.num_rows}, columns=\{self.source.columns.length()})"
  for index in 0..<self.steps.length() {
    let detail = match self.steps[index] {
      Filter(predicate) => "Filter \{predicate.describe()}"
      Project(columns) => "Project [\{columns.join(", ")}]"
      Limit(count) => "Limit \{count}"
      Sort(column, descending) =>
        "Sort \{column} \{if descending { "DESC" } else { "ASC" }} NULLS LAST"
      GroupUtf8SumInt32(key, value, sum_alias, count_alias) =>
        "GroupBy \{key}; SUM(\{value}) AS \{sum_alias}; COUNT(*) AS \{count_alias}"
      InnerJoin(right, left_key, right_key) =>
        "InnerJoin left.\{left_key} = right.\{right_key} (right rows=\{right.num_rows})"
    }
    text = text + "\n\{index + 1}: " + detail
  }
  text
}

///|
/// Execute the plan from left to right. Every produced batch is revalidated by
/// `shunge/arrow`, so query operators cannot emit malformed Arrow data.
pub fn Query::execute(self : Query) -> Result[@arrow.RecordBatch, QueryError] {
  let mut current = self.source
  match validate_existing_batch(current) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  for step in self.steps {
    let next = match step {
      Filter(predicate) => filter_batch(current, predicate)
      Project(columns) => project_batch(current, columns)
      Limit(count) => limit_batch(current, count)
      Sort(column, descending) => sort_batch(current, column, descending)
      GroupUtf8SumInt32(key, value, sum_alias, count_alias) =>
        group_utf8_sum_int32(current, key, value, sum_alias, count_alias)
      InnerJoin(right, left_key, right_key) =>
        inner_join_batch(current, right, left_key, right_key)
    }
    match next {
      Ok(batch) => current = batch
      Err(error) => return Err(error)
    }
  }
  Ok(current)
}
