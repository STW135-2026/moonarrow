///|
/// Errors reported while reading the small, read-only FlatBuffers subset used
/// by Arrow IPC metadata.
pub(all) enum FlatbufferError {
  OutOfBounds(Int, Int, Int)
  InvalidRoot(Int)
  InvalidTable(Int)
  InvalidUtf8(Int, Int)
} derive(Eq, Debug)

///|
/// A bounds-checked little-endian FlatBuffers reader.
pub struct Reader {
  data : Bytes
}

///|
pub fn Reader::new(data : Bytes) -> Reader {
  { data, }
}

///|
pub fn Reader::len(self : Reader) -> Int {
  self.data.length()
}

///|
fn Reader::check(
  self : Reader,
  offset : Int,
  length : Int,
) -> Result[Unit, FlatbufferError] {
  if offset < 0 || length < 0 || offset > self.len() - length {
    Err(OutOfBounds(offset, length, self.len()))
  } else {
    Ok(())
  }
}

///|
pub fn Reader::read_u8(
  self : Reader,
  offset : Int,
) -> Result[Int, FlatbufferError] {
  match self.check(offset, 1) {
    Err(error) => Err(error)
    Ok(_) => Ok(self.data[offset].to_int())
  }
}

///|
pub fn Reader::read_u16(
  self : Reader,
  offset : Int,
) -> Result[Int, FlatbufferError] {
  match self.check(offset, 2) {
    Err(error) => Err(error)
    Ok(_) =>
      Ok(self.data[offset].to_int() | (self.data[offset + 1].to_int() << 8))
  }
}

///|
pub fn Reader::read_i16(
  self : Reader,
  offset : Int,
) -> Result[Int, FlatbufferError] {
  self
  .read_u16(offset)
  .map(value => if value >= 0x8000 { value - 0x10000 } else { value })
}

///|
pub fn Reader::read_i32(
  self : Reader,
  offset : Int,
) -> Result[Int, FlatbufferError] {
  match self.check(offset, 4) {
    Err(error) => Err(error)
    Ok(_) => {
      let value = self.data[offset].to_uint() |
        (self.data[offset + 1].to_uint() << 8) |
        (self.data[offset + 2].to_uint() << 16) |
        (self.data[offset + 3].to_uint() << 24)
      Ok(value.reinterpret_as_int())
    }
  }
}

///|
pub fn Reader::read_i64(
  self : Reader,
  offset : Int,
) -> Result[Int64, FlatbufferError] {
  match self.check(offset, 8) {
    Err(error) => Err(error)
    Ok(_) => {
      let mut value = 0UL
      for i in 0..<8 {
        value = value | (self.data[offset + i].to_uint64() << (i * 8))
      }
      Ok(value.reinterpret_as_int64())
    }
  }
}

///|
pub fn Reader::read_u64(
  self : Reader,
  offset : Int,
) -> Result[UInt64, FlatbufferError] {
  self.read_i64(offset).map(value => value.reinterpret_as_uint64())
}

///|
pub fn Reader::slice(
  self : Reader,
  offset : Int,
  length : Int,
) -> Result[Bytes, FlatbufferError] {
  match self.check(offset, length) {
    Err(error) => Err(error)
    Ok(_) => {
      guard self.data.get_view(start=offset, end=offset + length) is Some(view) else {
        return Err(OutOfBounds(offset, length, self.len()))
      }
      Ok(Bytes::from_array(view.to_array()))
    }
  }
}

///|
pub fn Reader::root_table(self : Reader) -> Result[Table, FlatbufferError] {
  match self.read_i32(0) {
    Err(_) => Err(InvalidRoot(self.len()))
    Ok(relative) =>
      if relative < 4 || relative >= self.len() {
        Err(InvalidRoot(relative))
      } else {
        Table::from_position(self, relative)
      }
  }
}

///|
pub struct Table {
  reader : Reader
  pos : Int
}

///|
fn Table::from_position(
  reader : Reader,
  pos : Int,
) -> Result[Table, FlatbufferError] {
  match reader.read_i32(pos) {
    Err(_) => Err(InvalidTable(pos))
    Ok(vtable_distance) => {
      let vtable = pos - vtable_distance
      // FlatBuffers may deduplicate a vtable that was already emitted for a
      // later table. In that case the signed distance is negative and the
      // shared vtable is physically after the table object.
      if vtable_distance == 0 || vtable < 0 || vtable >= reader.len() {
        return Err(InvalidTable(pos))
      }
      match (reader.read_u16(vtable), reader.read_u16(vtable + 2)) {
        (Ok(vtable_length), Ok(object_length)) => {
          if vtable_length < 4 || object_length < 4 {
            return Err(InvalidTable(pos))
          }
          match
            (
              reader.check(vtable, vtable_length),
              reader.check(pos, object_length),
            ) {
            (Ok(_), Ok(_)) => Ok({ reader, pos, })
            _ => Err(InvalidTable(pos))
          }
        }
        _ => Err(InvalidTable(pos))
      }
    }
  }
}

///|
fn Table::field_pos(self : Table, slot : Int) -> Result[Int?, FlatbufferError] {
  if slot < 0 {
    return Err(InvalidTable(self.pos))
  }
  let vtable_distance = match self.reader.read_i32(self.pos) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let vtable = self.pos - vtable_distance
  let vtable_length = match self.reader.read_u16(vtable) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let entry = 4 + slot * 2
  if entry + 2 > vtable_length {
    return Ok(None)
  }
  let relative = match self.reader.read_u16(vtable + entry) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if relative == 0 {
    return Ok(None)
  }
  let object_length = match self.reader.read_u16(vtable + 2) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if relative >= object_length {
    return Err(InvalidTable(self.pos))
  }
  Ok(Some(self.pos + relative))
}

///|
pub fn Table::u8(
  self : Table,
  slot : Int,
  default : Int,
) -> Result[Int, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(default)
    Ok(Some(pos)) => self.reader.read_u8(pos)
  }
}

///|
pub fn Table::bool(
  self : Table,
  slot : Int,
  default : Bool,
) -> Result[Bool, FlatbufferError] {
  self.u8(slot, if default { 1 } else { 0 }).map(value => value != 0)
}

///|
pub fn Table::i16(
  self : Table,
  slot : Int,
  default : Int,
) -> Result[Int, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(default)
    Ok(Some(pos)) => self.reader.read_i16(pos)
  }
}

///|
pub fn Table::i32(
  self : Table,
  slot : Int,
  default : Int,
) -> Result[Int, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(default)
    Ok(Some(pos)) => self.reader.read_i32(pos)
  }
}

///|
pub fn Table::i64(
  self : Table,
  slot : Int,
  default : Int64,
) -> Result[Int64, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(default)
    Ok(Some(pos)) => self.reader.read_i64(pos)
  }
}

///|
pub fn Table::table(
  self : Table,
  slot : Int,
) -> Result[Table?, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(None)
    Ok(Some(pos)) =>
      match self.reader.read_i32(pos) {
        Err(error) => Err(error)
        Ok(relative) =>
          Table::from_position(self.reader, pos + relative).map(table => {
            Some(table)
          })
      }
  }
}

///|
pub fn Table::vector(
  self : Table,
  slot : Int,
) -> Result[Vector?, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(None)
    Ok(Some(pos)) =>
      match self.reader.read_i32(pos) {
        Err(error) => Err(error)
        Ok(relative) => {
          let vector_pos = pos + relative
          match self.reader.read_i32(vector_pos) {
            Err(error) => Err(error)
            Ok(length) =>
              if relative <= 0 || length < 0 {
                Err(InvalidTable(self.pos))
              } else {
                Ok(
                  Some({
                    reader: self.reader,
                    start: vector_pos + 4,
                    len: length,
                  }),
                )
              }
          }
        }
      }
  }
}

///|
pub fn Table::string(
  self : Table,
  slot : Int,
) -> Result[String?, FlatbufferError] {
  match self.field_pos(slot) {
    Err(error) => Err(error)
    Ok(None) => Ok(None)
    Ok(Some(pos)) => {
      let relative = match self.reader.read_i32(pos) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let string_pos = pos + relative
      let length = match self.reader.read_i32(string_pos) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if relative <= 0 || length < 0 {
        return Err(InvalidTable(self.pos))
      }
      let raw = match self.reader.slice(string_pos + 4, length) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let decoded = @utf8.decode_lossy(raw)
      if @utf8.encode(decoded) != raw {
        Err(InvalidUtf8(string_pos + 4, length))
      } else {
        Ok(Some(decoded))
      }
    }
  }
}

///|
pub struct Vector {
  reader : Reader
  start : Int
  len : Int
}

///|
pub fn Vector::len(self : Vector) -> Int {
  self.len
}

///|
pub fn Vector::table(
  self : Vector,
  index : Int,
) -> Result[Table, FlatbufferError] {
  if index < 0 || index >= self.len {
    return Err(OutOfBounds(index, 1, self.len))
  }
  let element = self.start + index * 4
  match self.reader.read_i32(element) {
    Err(error) => Err(error)
    Ok(relative) => Table::from_position(self.reader, element + relative)
  }
}

///|
pub fn Vector::struct_i64(
  self : Vector,
  index : Int,
  struct_size : Int,
  field_offset : Int,
) -> Result[Int64, FlatbufferError] {
  if index < 0 ||
    index >= self.len ||
    struct_size <= 0 ||
    field_offset < 0 ||
    field_offset > struct_size - 8 {
    return Err(OutOfBounds(index, 1, self.len))
  }
  self.reader.read_i64(self.start + index * struct_size + field_offset)
}
