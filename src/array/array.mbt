///|
pub(all) enum ArrayError {
  IndexOutOfBounds(Int, Int)
  InvalidSlice(Int, Int, Int)
  LengthMismatch(Int, Int)
} derive(Eq, Debug)

///|
fn validity_get(validity : @bitmap.Bitmap?, index : Int) -> Bool {
  match validity {
    None => true
    Some(bits) => bits.get(index).unwrap_or(false)
  }
}

///|
fn validity_null_count(validity : @bitmap.Bitmap?) -> Int {
  match validity {
    None => 0
    Some(bits) => bits.count_unset()
  }
}

///|
pub struct Int32Array {
  values : Array[Int]
  validity : @bitmap.Bitmap?
} derive(Eq, Debug)

///|
pub fn Int32Array::from_values(values : Array[Int]) -> Int32Array {
  { values: values.copy(), validity: None, }
}

///|
pub fn Int32Array::from_options(values : Array[Int?]) -> Int32Array {
  let physical : Array[Int] = []
  let validity = @bitmap.BitmapBuilder::new()
  for value in values {
    match value {
      Some(value) => {
        physical.push(value)
        validity.append(true)
      }
      None => {
        physical.push(0)
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
pub fn Int32Array::len(self : Int32Array) -> Int {
  self.values.length()
}

///|
pub fn Int32Array::null_count(self : Int32Array) -> Int {
  validity_null_count(self.validity)
}

///|
pub fn Int32Array::get(
  self : Int32Array,
  index : Int,
) -> Result[Int?, ArrayError] {
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
pub fn Int32Array::to_options(self : Int32Array) -> Array[Int?] {
  Array::makei(self.len(), i => {
    if validity_get(self.validity, i) {
      Some(self.values[i])
    } else {
      None
    }
  })
}

///|
pub fn Int32Array::slice(
  self : Int32Array,
  offset : Int,
  length : Int,
) -> Result[Int32Array, ArrayError] {
  if offset < 0 || length < 0 || offset + length > self.len() {
    return Err(InvalidSlice(offset, length, self.len()))
  }
  Ok(
    Int32Array::from_options(
      Array::makei(length, i => self.get(offset + i).unwrap()),
    ),
  )
}

///|
pub struct Float64Array {
  values : Array[Double]
  validity : @bitmap.Bitmap?
} derive(Eq, Debug)

///|
pub fn Float64Array::from_values(values : Array[Double]) -> Float64Array {
  { values: values.copy(), validity: None, }
}

///|
pub fn Float64Array::from_options(values : Array[Double?]) -> Float64Array {
  let physical : Array[Double] = []
  let validity = @bitmap.BitmapBuilder::new()
  for value in values {
    match value {
      Some(value) => {
        physical.push(value)
        validity.append(true)
      }
      None => {
        physical.push(0.0)
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
pub fn Float64Array::len(self : Float64Array) -> Int {
  self.values.length()
}

///|
pub fn Float64Array::null_count(self : Float64Array) -> Int {
  validity_null_count(self.validity)
}

///|
pub fn Float64Array::get(
  self : Float64Array,
  index : Int,
) -> Result[Double?, ArrayError] {
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
pub fn Float64Array::to_options(self : Float64Array) -> Array[Double?] {
  Array::makei(self.len(), i => {
    if validity_get(self.validity, i) {
      Some(self.values[i])
    } else {
      None
    }
  })
}

///|
pub fn Float64Array::slice(
  self : Float64Array,
  offset : Int,
  length : Int,
) -> Result[Float64Array, ArrayError] {
  if offset < 0 || length < 0 || offset + length > self.len() {
    return Err(InvalidSlice(offset, length, self.len()))
  }
  Ok(
    Float64Array::from_options(
      Array::makei(length, i => self.get(offset + i).unwrap()),
    ),
  )
}

///|
/// A bit-packed boolean array. Values and validity use the same Arrow bitmap
/// convention, but remain separate buffers.
pub struct BoolArray {
  values : @bitmap.Bitmap
  validity : @bitmap.Bitmap?
} derive(Eq, Debug)

///|
pub fn BoolArray::from_values(values : Array[Bool]) -> BoolArray {
  { values: @bitmap.Bitmap::from_bools(values), validity: None, }
}

///|
pub fn BoolArray::from_options(values : Array[Bool?]) -> BoolArray {
  let physical = @bitmap.BitmapBuilder::new()
  let validity = @bitmap.BitmapBuilder::new()
  for value in values {
    match value {
      Some(value) => {
        physical.append(value)
        validity.append(true)
      }
      None => {
        physical.append(false)
        validity.append(false)
      }
    }
  }
  let validity = validity.finish()
  {
    values: physical.finish(),
    validity: if validity.count_unset() == 0 {
      None
    } else {
      Some(validity)
    },
  }
}

///|
pub fn BoolArray::len(self : BoolArray) -> Int {
  self.values.len()
}

///|
pub fn BoolArray::null_count(self : BoolArray) -> Int {
  validity_null_count(self.validity)
}

///|
pub fn BoolArray::get(
  self : BoolArray,
  index : Int,
) -> Result[Bool?, ArrayError] {
  if index < 0 || index >= self.len() {
    return Err(IndexOutOfBounds(index, self.len()))
  }
  if validity_get(self.validity, index) {
    Ok(self.values.get(index))
  } else {
    Ok(None)
  }
}

///|
pub fn BoolArray::to_options(self : BoolArray) -> Array[Bool?] {
  Array::makei(self.len(), i => {
    if validity_get(self.validity, i) {
      self.values.get(i)
    } else {
      None
    }
  })
}

///|
pub fn BoolArray::slice(
  self : BoolArray,
  offset : Int,
  length : Int,
) -> Result[BoolArray, ArrayError] {
  if offset < 0 || length < 0 || offset + length > self.len() {
    return Err(InvalidSlice(offset, length, self.len()))
  }
  Ok(
    BoolArray::from_options(
      Array::makei(length, i => self.get(offset + i).unwrap()),
    ),
  )
}

///|
/// UTF-8 strings stored in Arrow's canonical offsets + values layout.
pub struct Utf8Array {
  offsets : Array[Int]
  data : Array[Byte]
  validity : @bitmap.Bitmap?
} derive(Eq, Debug)

///|
pub fn Utf8Array::from_values(values : Array[String]) -> Utf8Array {
  Utf8Array::from_options(values.map(value => Some(value)))
}

///|
pub fn Utf8Array::from_options(values : Array[String?]) -> Utf8Array {
  let offsets : Array[Int] = [0]
  let data : Array[Byte] = []
  let validity = @bitmap.BitmapBuilder::new()
  for value in values {
    match value {
      Some(value) => {
        for byte in @utf8.encode(value) {
          data.push(byte)
        }
        validity.append(true)
      }
      None => validity.append(false)
    }
    offsets.push(data.length())
  }
  let validity = validity.finish()
  {
    offsets,
    data,
    validity: if validity.count_unset() == 0 {
      None
    } else {
      Some(validity)
    },
  }
}

///|
pub fn Utf8Array::len(self : Utf8Array) -> Int {
  self.offsets.length() - 1
}

///|
pub fn Utf8Array::null_count(self : Utf8Array) -> Int {
  validity_null_count(self.validity)
}

///|
pub fn Utf8Array::data_length(self : Utf8Array) -> Int {
  self.data.length()
}

///|
pub fn Utf8Array::get(
  self : Utf8Array,
  index : Int,
) -> Result[String?, ArrayError] {
  if index < 0 || index >= self.len() {
    return Err(IndexOutOfBounds(index, self.len()))
  }
  if !validity_get(self.validity, index) {
    return Ok(None)
  }
  let start = self.offsets[index]
  let end = self.offsets[index + 1]
  let bytes = Bytes::from_array(self.data.clamped_view(start~, end~))
  Ok(Some(@utf8.decode_lossy(bytes)))
}

///|
pub fn Utf8Array::to_options(self : Utf8Array) -> Array[String?] {
  Array::makei(self.len(), i => self.get(i).unwrap())
}

///|
pub fn Utf8Array::slice(
  self : Utf8Array,
  offset : Int,
  length : Int,
) -> Result[Utf8Array, ArrayError] {
  if offset < 0 || length < 0 || offset + length > self.len() {
    return Err(InvalidSlice(offset, length, self.len()))
  }
  Ok(
    Utf8Array::from_options(
      Array::makei(length, i => self.get(offset + i).unwrap()),
    ),
  )
}
