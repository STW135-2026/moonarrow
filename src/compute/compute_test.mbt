///|
test "sum and mean ignore nulls" {
  let values = @array.Int32Array::from_options([
    Some(10),
    None,
    Some(20),
    Some(-3),
  ])
  assert_eq(@compute.sum_int32(values), Some(27L))
  assert_eq(@compute.mean_int32(values), Some(9.0))
  assert_eq(@compute.min_max_int32(values), Some((-3, 20)))
}

///|
test "aggregates return none for all-null input" {
  let values = @array.Int32Array::from_options([None, None])
  assert_eq(@compute.sum_int32(values), None)
  assert_eq(@compute.mean_int32(values), None)
  assert_eq(@compute.min_max_int32(values), None)
}

///|
test "comparison and filtering preserve input nulls" {
  let values = @array.Int32Array::from_options([
    Some(10),
    None,
    Some(30),
    Some(5),
  ])
  let predicate = @compute.greater_than_int32(values, 8)
  assert_eq(predicate.to_options(), [Some(true), None, Some(true), Some(false)])
  guard @compute.filter_int32(values, predicate) is Ok(filtered) else {
    fail("filter should succeed")
  }
  assert_eq(filtered.to_options(), [Some(10), Some(30)])
}

///|
test "filter validates mask length" {
  let values = @array.Int32Array::from_values([1, 2, 3])
  let predicate = @array.BoolArray::from_values([true])
  assert_true(
    @compute.filter_int32(values, predicate) is Err(@array.LengthMismatch(1, 3)),
  )
}

///|
test "int64 comparison and filtering preserve nulls" {
  let values = @array.Int64Array::from_options([
    Some(4_294_967_296L),
    None,
    Some(-1L),
  ])
  let predicate = @compute.greater_than_int64(values, 0L)
  assert_eq(predicate.to_options(), [Some(true), None, Some(false)])
  assert_eq(
    @compute.filter_int64(values, predicate).map(value => value.to_options()),
    Ok([Some(4_294_967_296L)]),
  )
}

///|
test "binary filtering keeps arbitrary payloads" {
  let values = @array.BinaryArray::from_options([
    Some(b"\x00\xff"),
    None,
    Some(b"Moon"),
  ])
  let predicate = @array.BoolArray::from_values([true, false, true])
  assert_eq(
    @compute.filter_binary(values, predicate).map(value => value.to_options()),
    Ok([Some(b"\x00\xff"), Some(b"Moon")]),
  )
}

///|
test "take validates every index" {
  let values = @array.Int32Array::from_options([Some(10), None, Some(30)])
  guard @compute.take_int32(values, [2, 0, 1]) is Ok(taken) else {
    fail("take should succeed")
  }
  assert_eq(taken.to_options(), [Some(30), Some(10), None])
  assert_true(
    @compute.take_int32(values, [3]) is Err(@array.IndexOutOfBounds(3, 3)),
  )
}
