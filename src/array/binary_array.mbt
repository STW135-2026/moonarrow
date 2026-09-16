///|
/// Variable-width binary values stored in Arrow's offsets + data layout.
pub struct BinaryArray {
  offsets : Array[Int]
  data : Array[Byte]
  validity : @bitmap.Bitmap?
} derive(Eq, Debug)

///|
pub fn BinaryArray::from_values(values : Array[Bytes]) -> BinaryArray {
  BinaryArray::from_options(values.map(value => Some(value)))
}

///|
pub fn BinaryArray::from_options(values : Array[Bytes?]) -> BinaryArray {
  let offsets : Array[Int] = [0]
  let data : Array[Byte] = []
  let validity = @bitmap.BitmapBuilder::new()
  for value in values {
    match value {
      Some(value) => {
        for byte in value {
          data.push(byte)
        }
        validity.append(true)
      }
      None => validity.append(false)
    }
    offsets.push(data.length())
  }
  let bits = validity.finish()
  {
    offsets,
    data,
    validity: if bits.count_unset() == 0 {
      None
    } else {
      Some(bits)
    },
  }
}

///|
pub fn BinaryArray::len(self : BinaryArray) -> Int {
  self.offsets.length() - 1
}

///|
pub fn BinaryArray::null_count(self : BinaryArray) -> Int {
  validity_null_count(self.validity)
}

///|
pub fn BinaryArray::data_length(self : BinaryArray) -> Int {
  self.data.length()
}

///|
pub fn BinaryArray::get(
  self : BinaryArray,
  index : Int,
) -> Result[Bytes?, ArrayError] {
  if index < 0 || index >= self.len() {
    return Err(IndexOutOfBounds(index, self.len()))
  }
  if !validity_get(self.validity, index) {
    return Ok(None)
  }
  let start = self.offsets[index]
  let end = self.offsets[index + 1]
  Ok(Some(Bytes::from_array(self.data.clamped_view(start~, end~).to_owned())))
}

///|
pub fn BinaryArray::to_options(self : BinaryArray) -> Array[Bytes?] {
  Array::makei(self.len(), i => self.get(i).unwrap())
}

///|
pub fn BinaryArray::slice(
  self : BinaryArray,
  offset : Int,
  length : Int,
) -> Result[BinaryArray, ArrayError] {
  if offset < 0 || length < 0 || offset + length > self.len() {
    return Err(InvalidSlice(offset, length, self.len()))
  }
  Ok(
    BinaryArray::from_options(
      Array::makei(length, i => self.get(offset + i).unwrap()),
    ),
  )
}
