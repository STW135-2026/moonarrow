///|
test "encapsulation parser accepts an empty modern stream" {
  let stream_end = b"\xff\xff\xff\xff\x00\x00\x00\x00"
  assert_eq(
    @ipc.parse_messages(stream_end).map(messages => messages.length()),
    Ok(0),
  )
}

///|
test "encapsulation parser rejects negative metadata lengths" {
  assert_true(
    @ipc.parse_messages(b"\xfe\xff\xff\xff")
    is Err(@ipc.InvalidMetadataLength(-2)),
  )
}

///|
test "encapsulation parser reports truncated continuation prefixes" {
  assert_true(
    @ipc.parse_messages(b"\xff\xff\xff\xff") is Err(@ipc.Truncated(0, 8, 4)),
  )
}
