///|
test "bitmap packs bits in Arrow LSB order" {
  let bitmap = @bitmap.Bitmap::from_bools([
    true, false, true, true, false, false, false, true, true,
  ])
  assert_eq(bitmap.len(), 9)
  assert_eq(bitmap.count_set(), 5)
  assert_eq(bitmap.count_unset(), 4)
  assert_eq(bitmap.to_bytes().to_array(), [b'\x8D', b'\x01'])
}

///|
test "bitmap bounds are explicit" {
  let bitmap = @bitmap.Bitmap::from_bools([true, false])
  assert_eq(bitmap.get(-1), None)
  assert_eq(bitmap.get(0), Some(true))
  assert_eq(bitmap.get(1), Some(false))
  assert_eq(bitmap.get(2), None)
}

///|
test "bitmap slice repacks unaligned offsets" {
  let bitmap = @bitmap.Bitmap::from_bools([true, false, true, true, false])
  guard bitmap.slice(1, 3) is Ok(slice) else { fail("slice should be valid") }
  assert_eq(slice.to_bools(), [false, true, true])
  assert_eq(slice.to_bytes().to_array(), [b'\x06'])
}

///|
test "bitmap rejects invalid slices" {
  let bitmap = @bitmap.Bitmap::from_bools([true])
  assert_true(bitmap.slice(1, 1) is Err(@bitmap.InvalidSlice(1, 1, 1)))
}
