///|
test "int32 array separates validity from physical values" {
  let values = @array.Int32Array::from_options([Some(10), None, Some(-3)])
  assert_eq(values.len(), 3)
  assert_eq(values.null_count(), 1)
  assert_eq(values.get(0), Ok(Some(10)))
  assert_eq(values.get(1), Ok(None))
  assert_eq(values.get(2), Ok(Some(-3)))
}

///|
test "int32 array reports out of bounds" {
  let values = @array.Int32Array::from_values([1, 2])
  assert_true(values.get(2) is Err(@array.IndexOutOfBounds(2, 2)))
}

///|
test "primitive array slicing preserves nulls" {
  let values = @array.Int32Array::from_options([Some(1), None, Some(3), Some(4)])
  guard values.slice(1, 2) is Ok(slice) else { fail("slice should be valid") }
  assert_eq(slice.to_options(), [None, Some(3)])
}

///|
test "float64 array supports nullable values" {
  let values = @array.Float64Array::from_options([Some(1.5), None, Some(-2.25)])
  assert_eq(values.null_count(), 1)
  assert_eq(values.to_options(), [Some(1.5), None, Some(-2.25)])
}

///|
test "boolean array bit-packs values and validity" {
  let values = @array.BoolArray::from_options([
    Some(true),
    None,
    Some(false),
    Some(true),
  ])
  assert_eq(values.null_count(), 1)
  assert_eq(values.to_options(), [Some(true), None, Some(false), Some(true)])
}

///|
test "utf8 array uses byte offsets, not UTF-16 offsets" {
  let values = @array.Utf8Array::from_options([
    Some("MoonBit"),
    Some("月兔"),
    None,
    Some("🦊"),
  ])
  assert_eq(values.len(), 4)
  assert_eq(values.null_count(), 1)
  assert_eq(values.data_length(), 17)
  assert_eq(values.get(1), Ok(Some("月兔")))
  assert_eq(values.get(2), Ok(None))
  assert_eq(values.get(3), Ok(Some("🦊")))
}
