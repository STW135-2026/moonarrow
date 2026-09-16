///|
/// Logical data types supported by the first MoonArrow milestone.
///
/// The enum intentionally starts small. New physical layouts will be added only
/// when their invariants and IPC representation are implemented and tested.
pub(all) enum DataType {
  Boolean
  Int32
  Int64
  Float64
  Utf8
  Binary
} derive(Eq, Debug)

///|
pub fn DataType::name(self : DataType) -> String {
  match self {
    Boolean => "bool"
    Int32 => "int32"
    Int64 => "int64"
    Float64 => "float64"
    Utf8 => "utf8"
    Binary => "binary"
  }
}

///|
/// A field binds a stable column name to a logical type and nullability rule.
pub(all) struct Field {
  name : String
  data_type : DataType
  nullable : Bool
} derive(Eq, Debug)

///|
pub fn Field::new(
  name : String,
  data_type : DataType,
  nullable? : Bool = true,
) -> Field {
  { name, data_type, nullable, }
}

///|
pub(all) enum SchemaError {
  EmptyFieldName(Int)
  DuplicateFieldName(String)
} derive(Eq, Debug)

///|
/// An ordered set of uniquely named fields.
pub struct Schema {
  fields : Array[Field]
} derive(Eq, Debug)

///|
pub fn Schema::new(fields : Array[Field]) -> Result[Schema, SchemaError] {
  for i in 0..<fields.length() {
    if fields[i].name == "" {
      return Err(EmptyFieldName(i))
    }
    for j in 0..<i {
      if fields[i].name == fields[j].name {
        return Err(DuplicateFieldName(fields[i].name))
      }
    }
  }
  Ok({ fields: fields.copy(), })
}

///|
pub fn Schema::len(self : Schema) -> Int {
  self.fields.length()
}

///|
pub fn Schema::is_empty(self : Schema) -> Bool {
  self.fields.is_empty()
}

///|
pub fn Schema::field(self : Schema, index : Int) -> Field? {
  self.fields.get(index)
}

///|
pub fn Schema::field_index(self : Schema, name : String) -> Int? {
  for i in 0..<self.fields.length() {
    if self.fields[i].name == name {
      return Some(i)
    }
  }
  None
}

///|
pub fn Schema::fields(self : Schema) -> Array[Field] {
  self.fields.copy()
}
