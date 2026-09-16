///|
pub(all) enum Column {
  Binary(@array.BinaryArray)
  Bool(@array.BoolArray)
  Int32(@array.Int32Array)
  Int64(@array.Int64Array)
  Float64(@array.Float64Array)
  Utf8(@array.Utf8Array)
} derive(Eq, Debug)

///|
pub fn Column::len(self : Column) -> Int {
  match self {
    Binary(column) => column.len()
    Bool(column) => column.len()
    Int32(column) => column.len()
    Int64(column) => column.len()
    Float64(column) => column.len()
    Utf8(column) => column.len()
  }
}

///|
pub fn Column::null_count(self : Column) -> Int {
  match self {
    Binary(column) => column.null_count()
    Bool(column) => column.null_count()
    Int32(column) => column.null_count()
    Int64(column) => column.null_count()
    Float64(column) => column.null_count()
    Utf8(column) => column.null_count()
  }
}

///|
pub fn Column::data_type(self : Column) -> @types.DataType {
  match self {
    Binary(_) => @types.Binary
    Bool(_) => @types.Boolean
    Int32(_) => @types.Int32
    Int64(_) => @types.Int64
    Float64(_) => @types.Float64
    Utf8(_) => @types.Utf8
  }
}

///|
/// Render one value for diagnostics and CLI previews. Binary payloads are not
/// decoded as text; their byte length is reported instead.
pub fn Column::value_text(
  self : Column,
  index : Int,
) -> Result[String, @array.ArrayError] {
  match self {
    Binary(column) =>
      column
      .get(index)
      .map(value => {
        match value {
          None => "null"
          Some(bytes) => "<binary: \{bytes.length()} bytes>"
        }
      })
    Bool(column) =>
      column
      .get(index)
      .map(value => {
        match value {
          None => "null"
          Some(value) => "\{value}"
        }
      })
    Int32(column) =>
      column
      .get(index)
      .map(value => {
        match value {
          None => "null"
          Some(value) => "\{value}"
        }
      })
    Int64(column) =>
      column
      .get(index)
      .map(value => {
        match value {
          None => "null"
          Some(value) => "\{value}"
        }
      })
    Float64(column) =>
      column
      .get(index)
      .map(value => {
        match value {
          None => "null"
          Some(value) => "\{value}"
        }
      })
    Utf8(column) =>
      column
      .get(index)
      .map(value => {
        match value {
          None => "null"
          Some(value) => value
        }
      })
  }
}

///|
pub fn Column::slice(
  self : Column,
  offset : Int,
  length : Int,
) -> Result[Column, @array.ArrayError] {
  match self {
    Binary(column) => column.slice(offset, length).map(value => Binary(value))
    Bool(column) => column.slice(offset, length).map(value => Bool(value))
    Int32(column) => column.slice(offset, length).map(value => Int32(value))
    Int64(column) => column.slice(offset, length).map(value => Int64(value))
    Float64(column) => column.slice(offset, length).map(value => Float64(value))
    Utf8(column) => column.slice(offset, length).map(value => Utf8(value))
  }
}

///|
pub(all) enum RecordBatchError {
  ColumnCountMismatch(Int, Int)
  ColumnTypeMismatch(Int, @types.DataType, @types.DataType)
  ColumnLengthMismatch(Int, Int, Int)
  NonNullableColumnContainsNull(Int, Int)
  ComputeError(@array.ArrayError)
} derive(Eq, Debug)

///|
pub struct RecordBatch {
  schema : @types.Schema
  columns : Array[Column]
  row_count : Int
} derive(Eq, Debug)

///|
pub fn RecordBatch::new(
  schema : @types.Schema,
  columns : Array[Column],
) -> Result[RecordBatch, RecordBatchError] {
  if schema.len() != columns.length() {
    return Err(ColumnCountMismatch(columns.length(), schema.len()))
  }
  let row_count = if columns.is_empty() { 0 } else { columns[0].len() }
  for i in 0..<columns.length() {
    guard schema.field(i) is Some(field) else {
      return Err(ColumnCountMismatch(columns.length(), schema.len()))
    }
    let actual_type = columns[i].data_type()
    if actual_type != field.data_type {
      return Err(ColumnTypeMismatch(i, actual_type, field.data_type))
    }
    if columns[i].len() != row_count {
      return Err(ColumnLengthMismatch(i, columns[i].len(), row_count))
    }
    if !field.nullable && columns[i].null_count() > 0 {
      return Err(NonNullableColumnContainsNull(i, columns[i].null_count()))
    }
  }
  Ok({ schema, columns: columns.copy(), row_count, })
}

///|
pub fn RecordBatch::schema(self : RecordBatch) -> @types.Schema {
  self.schema
}

///|
pub fn RecordBatch::row_count(self : RecordBatch) -> Int {
  self.row_count
}

///|
pub fn RecordBatch::column_count(self : RecordBatch) -> Int {
  self.columns.length()
}

///|
pub fn RecordBatch::column(self : RecordBatch, index : Int) -> Column? {
  self.columns.get(index)
}

///|
pub fn RecordBatch::column_by_name(
  self : RecordBatch,
  name : String,
) -> Column? {
  match self.schema.field_index(name) {
    Some(index) => self.column(index)
    None => None
  }
}

///|
pub fn RecordBatch::filter(
  self : RecordBatch,
  predicate : @array.BoolArray,
) -> Result[RecordBatch, RecordBatchError] {
  let columns : Array[Column] = []
  for column in self.columns {
    let filtered = match column {
      Binary(values) =>
        @compute.filter_binary(values, predicate).map(values => Binary(values))
      Bool(values) =>
        @compute.filter_bool(values, predicate).map(values => Bool(values))
      Int32(values) =>
        @compute.filter_int32(values, predicate).map(values => Int32(values))
      Int64(values) =>
        @compute.filter_int64(values, predicate).map(values => Int64(values))
      Float64(values) =>
        @compute.filter_float64(values, predicate).map(values => Float64(values))
      Utf8(values) =>
        @compute.filter_utf8(values, predicate).map(values => Utf8(values))
    }
    match filtered {
      Ok(column) => columns.push(column)
      Err(error) => return Err(ComputeError(error))
    }
  }
  RecordBatch::new(self.schema, columns)
}
