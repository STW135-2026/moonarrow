///|
pub(all) enum DataFrameError {
  ColumnNotFound(String)
  ExpectedColumnType(String, @types.DataType, @types.DataType)
  InvalidLimit(Int)
  Array(@array.ArrayError)
  Schema(@types.SchemaError)
  RecordBatch(@record_batch.RecordBatchError)
} derive(Eq, Debug)

///|
/// A compact eager DataFrame facade over a validated RecordBatch.
pub struct DataFrame {
  batch : @record_batch.RecordBatch
} derive(Eq, Debug)

///|
pub fn DataFrame::from_record_batch(
  batch : @record_batch.RecordBatch,
) -> DataFrame {
  { batch, }
}

///|
pub fn DataFrame::record_batch(self : DataFrame) -> @record_batch.RecordBatch {
  self.batch
}

///|
pub fn DataFrame::schema(self : DataFrame) -> @types.Schema {
  self.batch.schema()
}

///|
pub fn DataFrame::row_count(self : DataFrame) -> Int {
  self.batch.row_count()
}

///|
pub fn DataFrame::column_count(self : DataFrame) -> Int {
  self.batch.column_count()
}

///|
pub fn DataFrame::column(
  self : DataFrame,
  name : String,
) -> @record_batch.Column? {
  self.batch.column_by_name(name)
}

///|
/// Project columns in the requested order. Unknown and duplicate names are
/// rejected rather than silently changed.
pub fn DataFrame::select(
  self : DataFrame,
  names : Array[String],
) -> Result[DataFrame, DataFrameError] {
  let fields : Array[@types.Field] = []
  let columns : Array[@record_batch.Column] = []
  for name in names {
    guard self.schema().field_index(name) is Some(index) else {
      return Err(ColumnNotFound(name))
    }
    fields.push(self.schema().field(index).unwrap())
    columns.push(self.batch.column(index).unwrap())
  }
  let schema = match @types.Schema::new(fields) {
    Ok(value) => value
    Err(error) => return Err(Schema(error))
  }
  match @record_batch.RecordBatch::new(schema, columns) {
    Ok(value) => Ok(DataFrame::from_record_batch(value))
    Err(error) => Err(RecordBatch(error))
  }
}

///|
pub fn DataFrame::filter(
  self : DataFrame,
  predicate : @array.BoolArray,
) -> Result[DataFrame, DataFrameError] {
  match self.batch.filter(predicate) {
    Ok(value) => Ok(DataFrame::from_record_batch(value))
    Err(error) => Err(RecordBatch(error))
  }
}

///|
/// Keep rows where a Boolean column is true. Null predicates are treated as
/// false, matching the lower-level filter kernel.
pub fn DataFrame::filter_by_bool(
  self : DataFrame,
  name : String,
) -> Result[DataFrame, DataFrameError] {
  match self.column(name) {
    None => Err(ColumnNotFound(name))
    Some(@record_batch.Bool(predicate)) => self.filter(predicate)
    Some(column) =>
      Err(ExpectedColumnType(name, @types.Boolean, column.data_type()))
  }
}

///|
pub fn DataFrame::where_int32_gt(
  self : DataFrame,
  name : String,
  threshold : Int,
) -> Result[DataFrame, DataFrameError] {
  match self.column(name) {
    None => Err(ColumnNotFound(name))
    Some(@record_batch.Int32(values)) =>
      self.filter(@compute.greater_than_int32(values, threshold))
    Some(column) =>
      Err(ExpectedColumnType(name, @types.Int32, column.data_type()))
  }
}

///|
/// Return at most the first `count` rows without changing column types.
pub fn DataFrame::limit(
  self : DataFrame,
  count : Int,
) -> Result[DataFrame, DataFrameError] {
  if count < 0 {
    return Err(InvalidLimit(count))
  }
  let length = if count < self.row_count() { count } else { self.row_count() }
  let columns : Array[@record_batch.Column] = []
  for index in 0..<self.column_count() {
    match self.batch.column(index).unwrap().slice(0, length) {
      Ok(value) => columns.push(value)
      Err(error) => return Err(Array(error))
    }
  }
  match @record_batch.RecordBatch::new(self.schema(), columns) {
    Ok(value) => Ok(DataFrame::from_record_batch(value))
    Err(error) => Err(RecordBatch(error))
  }
}

///|
pub fn DataFrame::sum_int32(
  self : DataFrame,
  name : String,
) -> Result[Int64?, DataFrameError] {
  match self.column(name) {
    None => Err(ColumnNotFound(name))
    Some(@record_batch.Int32(values)) => Ok(@compute.sum_int32(values))
    Some(column) =>
      Err(ExpectedColumnType(name, @types.Int32, column.data_type()))
  }
}

///|
pub fn DataFrame::mean_int32(
  self : DataFrame,
  name : String,
) -> Result[Double?, DataFrameError] {
  match self.column(name) {
    None => Err(ColumnNotFound(name))
    Some(@record_batch.Int32(values)) => Ok(@compute.mean_int32(values))
    Some(column) =>
      Err(ExpectedColumnType(name, @types.Int32, column.data_type()))
  }
}
