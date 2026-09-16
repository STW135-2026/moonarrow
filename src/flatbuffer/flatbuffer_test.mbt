///|
test "reader decodes little-endian scalars with bounds checks" {
  let reader = @flatbuffer.Reader::new(
    b"\x78\x56\x34\x12\x08\x07\x06\x05\x04\x03\x02\x01",
  )
  assert_eq(reader.read_u16(0), Ok(0x5678))
  assert_eq(reader.read_i32(0), Ok(0x12345678))
  assert_eq(reader.read_i64(4), Ok(0x0102030405060708L))
  assert_true(reader.read_i32(9) is Err(@flatbuffer.OutOfBounds(9, 4, 12)))
}

///|
test "reader rejects invalid roots" {
  assert_true(
    @flatbuffer.Reader::new(b"\x03\x00\x00\x00").root_table()
    is Err(@flatbuffer.InvalidRoot(3)),
  )
}
