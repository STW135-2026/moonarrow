///|
test "int64 arrays preserve large values and nulls" {
  let values = @array.Int64Array::from_options([
    Some(9_223_372_036_854_775_000L),
    None,
    Some(-4_294_967_296L),
  ])
  assert_eq(values.len(), 3)
  assert_eq(values.null_count(), 1)
  assert_eq(values.to_options(), [
    Some(9_223_372_036_854_775_000L),
    None,
    Some(-4_294_967_296L),
  ])
}

///|
test "int64 slices validate bounds" {
  let values = @array.Int64Array::from_values([1L, 2L, 3L])
  assert_eq(
    values.slice(1, 2).map(value => value.to_options()),
    Ok([Some(2L), Some(3L)]),
  )
  assert_true(values.slice(2, 2) is Err(@array.InvalidSlice(2, 2, 3)))
  assert_true(values.get(-1) is Err(@array.IndexOutOfBounds(-1, 3)))
}
