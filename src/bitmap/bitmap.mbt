///|
pub(all) enum BitmapError {
  NegativeLength(Int)
  InvalidSlice(Int, Int, Int)
} derive(Eq, Debug)

///|
/// Arrow-compatible least-significant-bit-first packed bitmap.
pub struct Bitmap {
  bytes : Array[Byte]
  len : Int
  unset_count : Int
} derive(Eq, Debug)

///|
pub fn Bitmap::from_bools(values : Array[Bool]) -> Bitmap {
  let builder = BitmapBuilder::new()
  for value in values {
    builder.append(value)
  }
  builder.finish()
}

///|
pub fn Bitmap::all_valid(len : Int) -> Result[Bitmap, BitmapError] {
  if len < 0 {
    return Err(NegativeLength(len))
  }
  let builder = BitmapBuilder::new()
  for _ in 0..<len {
    builder.append(true)
  }
  Ok(builder.finish())
}

///|
pub fn Bitmap::all_null(len : Int) -> Result[Bitmap, BitmapError] {
  if len < 0 {
    return Err(NegativeLength(len))
  }
  let builder = BitmapBuilder::new()
  for _ in 0..<len {
    builder.append(false)
  }
  Ok(builder.finish())
}

///|
pub fn Bitmap::len(self : Bitmap) -> Int {
  self.len
}

///|
pub fn Bitmap::is_empty(self : Bitmap) -> Bool {
  self.len == 0
}

///|
pub fn Bitmap::count_set(self : Bitmap) -> Int {
  self.len - self.unset_count
}

///|
pub fn Bitmap::count_unset(self : Bitmap) -> Int {
  self.unset_count
}

///|
pub fn Bitmap::get(self : Bitmap, index : Int) -> Bool? {
  if index < 0 || index >= self.len {
    return None
  }
  let byte_index = index / 8
  let bit_index = index % 8
  let mask = 1 << bit_index
  Some((self.bytes[byte_index].to_int() & mask) != 0)
}

///|
pub fn Bitmap::to_bools(self : Bitmap) -> Array[Bool] {
  Array::makei(self.len, i => self.get(i).unwrap_or(false))
}

///|
pub fn Bitmap::to_bytes(self : Bitmap) -> Bytes {
  Bytes::from_array(self.bytes)
}

///|
pub fn Bitmap::slice(
  self : Bitmap,
  offset : Int,
  length : Int,
) -> Result[Bitmap, BitmapError] {
  if offset < 0 || length < 0 || offset + length > self.len {
    return Err(InvalidSlice(offset, length, self.len))
  }
  let builder = BitmapBuilder::new()
  for i in offset..<(offset + length) {
    builder.append(self.get(i).unwrap_or(false))
  }
  Ok(builder.finish())
}

///|
/// Incremental builder used by nullable arrays and compute kernels.
pub struct BitmapBuilder {
  bytes : Array[Byte]
  mut len : Int
  mut unset_count : Int
}

///|
pub fn BitmapBuilder::new() -> BitmapBuilder {
  { bytes: [], len: 0, unset_count: 0, }
}

///|
pub fn BitmapBuilder::append(self : BitmapBuilder, value : Bool) -> Unit {
  if self.len % 8 == 0 {
    self.bytes.push(b'\x00')
  }
  if value {
    let byte_index = self.len / 8
    let mask = 1 << (self.len % 8)
    self.bytes[byte_index] = (self.bytes[byte_index].to_int() | mask).to_byte()
  } else {
    self.unset_count = self.unset_count + 1
  }
  self.len = self.len + 1
}

///|
pub fn BitmapBuilder::len(self : BitmapBuilder) -> Int {
  self.len
}

///|
pub fn BitmapBuilder::finish(self : BitmapBuilder) -> Bitmap {
  { bytes: self.bytes.copy(), len: self.len, unset_count: self.unset_count, }
}
