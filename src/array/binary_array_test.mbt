///|
test "binary arrays preserve arbitrary bytes and nulls" {
  let values = @array.BinaryArray::from_options([
    Some(b"\x00\xffMoon"),
    None,
    Some(b""),
  ])
  assert_eq(values.len(), 3)
  assert_eq(values.null_count(), 1)
  assert_eq(values.data_length(), 6)
  assert_eq(values.to_options(), [Some(b"\x00\xffMoon"), None, Some(b"")])
}

///|
test "binary slices rebuild canonical offsets" {
  let values = @array.BinaryArray::from_values([b"alpha", b"beta", b"gamma"])
  assert_eq(
    values.slice(1, 2).map(value => value.to_options()),
    Ok([Some(b"beta"), Some(b"gamma")]),
  )
  assert_true(values.get(3) is Err(@array.IndexOutOfBounds(3, 3)))
}
