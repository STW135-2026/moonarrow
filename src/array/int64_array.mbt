///|
/// A nullable signed 64-bit Arrow primitive array.
pub struct Int64Array {
  values : Array[Int64]
  validity : @bitmap.Bitmap?
} derive(Eq, Debug)

///|
pub fn Int64Array::from_values(values : Array[Int64]) -> Int64Array {
  { values: values.copy(), validity: None, }
}

///|
pub fn Int64Array::from_options(values : Array[Int64?]) -> Int64Array {
  let physical : Array[Int64] = []
  let validity = @bitmap.BitmapBuilder::new()
  for value in values {
    match value {
      Some(value) => {
        physical.push(value)
        validity.append(true)
      }
      None => {
        physical.push(0L)
        validity.append(false)
      }
    }
  }
  let bits = validity.finish()
  {
    values: physical,
    validity: if bits.count_unset() == 0 {
      None
    } else {
      Some(bits)
    },
  }
}

///|
pub fn Int64Array::len(self : Int64Array) -> Int {
  self.values.length()
}

///|
pub fn Int64Array::null_count(self : Int64Array) -> Int {
  validity_null_count(self.validity)
}

///|
pub fn Int64Array::get(
  self : Int64Array,
  index : Int,
) -> Result[Int64?, ArrayError] {
  if index < 0 || index >= self.len() {
    return Err(IndexOutOfBounds(index, self.len()))
  }
  if validity_get(self.validity, index) {
    Ok(Some(self.values[index]))
  } else {
    Ok(None)
  }
}

///|
pub fn Int64Array::to_options(self : Int64Array) -> Array[Int64?] {
  Array::makei(self.len(), i => {
    if validity_get(self.validity, i) {
      Some(self.values[i])
    } else {
      None
    }
  })
}

///|
pub fn Int64Array::slice(
  self : Int64Array,
  offset : Int,
  length : Int,
) -> Result[Int64Array, ArrayError] {
  if offset < 0 || length < 0 || offset + length > self.len() {
    return Err(InvalidSlice(offset, length, self.len()))
  }
  Ok(
    Int64Array::from_options(
      Array::makei(length, i => self.get(offset + i).unwrap()),
    ),
  )
}
