///|
/// Errors are deliberately structured so callers can distinguish malformed
/// input from well-formed Arrow features that MoonArrow does not support yet.
pub(all) enum IpcError {
  Flatbuffer(@flatbuffer.FlatbufferError)
  Truncated(Int, Int, Int)
  InvalidMetadataLength(Int)
  IntegerOutOfRange(Int64)
  UnsupportedMetadataVersion(Int)
  UnsupportedMessageType(Int)
  MissingSchema
  MissingHeader(Int)
  BigEndianUnsupported
  UnsupportedType(Int)
  UnsupportedInteger(Int, Bool)
  UnsupportedFloat(Int)
  NestedFieldsUnsupported(String)
  DictionaryEncodingUnsupported(String)
  InvalidRecordLength(Int64)
  InvalidNodeCount(Int, Int)
  InvalidBufferCount(Int, Int)
  InvalidNode(Int, Int64, Int64)
  InvalidBuffer(Int, Int64, Int64, Int)
  InvalidValidity(Int, Int, Int)
  InvalidOffsets(Int, Int, Int)
  InvalidUtf8(Int, Int)
  Schema(@types.SchemaError)
  RecordBatch(@record_batch.RecordBatchError)
} derive(Eq, Debug)

///|
fn[T] lift_fb(
  result : Result[T, @flatbuffer.FlatbufferError],
) -> Result[T, IpcError] {
  result.map_err(error => Flatbuffer(error))
}

///|
fn checked_int(value : Int64) -> Result[Int, IpcError] {
  if value < 0L {
    return Err(IntegerOutOfRange(value))
  }
  let narrowed = value.to_int()
  if narrowed.to_int64() != value {
    Err(IntegerOutOfRange(value))
  } else {
    Ok(narrowed)
  }
}

///|
fn align8(value : Int) -> Int {
  (value + 7) & -8
}

///|
/// One decoded Arrow IPC envelope. Metadata and body remain immutable byte
/// sequences; schema and array decoding happen in the higher-level reader.
pub struct IpcMessage {
  metadata : Bytes
  body : Bytes
  version : Int
  header_type : Int
  body_length : Int
}

///|
pub fn IpcMessage::metadata_version(self : IpcMessage) -> Int {
  self.version
}

///|
pub fn IpcMessage::header_type(self : IpcMessage) -> Int {
  self.header_type
}

///|
pub fn IpcMessage::body_length(self : IpcMessage) -> Int {
  self.body_length
}

///|
fn parse_message_metadata(
  metadata : Bytes,
  body : Bytes,
) -> Result[IpcMessage, IpcError] {
  let root = match lift_fb(@flatbuffer.Reader::new(metadata).root_table()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let version = match lift_fb(root.i16(0, 0)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if version < 0 || version > 4 {
    return Err(UnsupportedMetadataVersion(version))
  }
  let header_type = match lift_fb(root.u8(1, 0)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let declared_body_length = match lift_fb(root.i64(3, 0L)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let body_length = match checked_int(declared_body_length) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if body_length != body.length() {
    return Err(Truncated(0, body_length, body.length()))
  }
  Ok({ metadata, body, version, header_type, body_length, })
}

///|
/// Parse the encapsulated-message framing used by Arrow IPC streams. Both the
/// current continuation marker and the legacy four-byte prefix are accepted.
pub fn parse_messages(data : Bytes) -> Result[Array[IpcMessage], IpcError] {
  let reader = @flatbuffer.Reader::new(data)
  let messages : Array[IpcMessage] = []
  let mut offset = 0
  while offset < data.length() {
    if data.length() - offset < 4 {
      return Err(Truncated(offset, 4, data.length() - offset))
    }
    let first = match lift_fb(reader.read_i32(offset)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let (prefix_length, metadata_length) = if first == -1 {
      if data.length() - offset < 8 {
        return Err(Truncated(offset, 8, data.length() - offset))
      }
      let length = match lift_fb(reader.read_i32(offset + 4)) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      (8, length)
    } else {
      (4, first)
    }
    if metadata_length == 0 {
      return Ok(messages)
    }
    if metadata_length < 0 {
      return Err(InvalidMetadataLength(metadata_length))
    }
    let metadata_start = offset + prefix_length
    let metadata = match
      lift_fb(reader.slice(metadata_start, metadata_length)) {
      Ok(value) => value
      Err(_) =>
        return Err(
          Truncated(
            metadata_start,
            metadata_length,
            data.length() - metadata_start,
          ),
        )
    }
    let metadata_end = metadata_start + metadata_length
    let body_start = align8(metadata_end)
    let root = match lift_fb(@flatbuffer.Reader::new(metadata).root_table()) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let declared_body_length = match lift_fb(root.i64(3, 0L)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let body_length = match checked_int(declared_body_length) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let body = match lift_fb(reader.slice(body_start, body_length)) {
      Ok(value) => value
      Err(_) =>
        return Err(
          Truncated(body_start, body_length, data.length() - body_start),
        )
    }
    let message = match parse_message_metadata(metadata, body) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    messages.push(message)
    offset = align8(body_start + body_length)
  }
  Ok(messages)
}

///|
fn message_header(message : IpcMessage) -> Result[@flatbuffer.Table, IpcError] {
  let root = match
    lift_fb(@flatbuffer.Reader::new(message.metadata).root_table()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match lift_fb(root.table(2)) {
    Ok(Some(value)) => Ok(value)
    Ok(None) => Err(MissingHeader(message.header_type))
    Err(error) => Err(error)
  }
}

///|
fn decode_field(field : @flatbuffer.Table) -> Result[@types.Field, IpcError] {
  let name = match lift_fb(field.string(0)) {
    Ok(Some(value)) => value
    Ok(None) => ""
    Err(error) => return Err(error)
  }
  let nullable = match lift_fb(field.bool(1, false)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let type_id = match lift_fb(field.u8(2, 0)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let type_table = match lift_fb(field.table(3)) {
    Ok(Some(value)) => value
    Ok(None) => return Err(UnsupportedType(type_id))
    Err(error) => return Err(error)
  }
  let data_type = match type_id {
    2 => {
      let bit_width = match lift_fb(type_table.i32(0, 0)) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let signed = match lift_fb(type_table.bool(1, false)) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if !signed {
        return Err(UnsupportedInteger(bit_width, signed))
      }
      match bit_width {
        32 => @types.Int32
        64 => @types.Int64
        _ => return Err(UnsupportedInteger(bit_width, signed))
      }
    }
    3 => {
      let precision = match lift_fb(type_table.i16(0, 0)) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if precision != 2 {
        return Err(UnsupportedFloat(precision))
      }
      @types.Float64
    }
    4 => @types.Binary
    5 => @types.Utf8
    6 => @types.Boolean
    _ => return Err(UnsupportedType(type_id))
  }
  match lift_fb(field.table(4)) {
    Ok(Some(_)) => return Err(DictionaryEncodingUnsupported(name))
    Ok(None) => ()
    Err(error) => return Err(error)
  }
  match lift_fb(field.vector(5)) {
    Ok(Some(children)) if children.len() > 0 =>
      return Err(NestedFieldsUnsupported(name))
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  Ok(@types.Field::new(name, data_type, nullable~))
}

///|
pub fn decode_schema(message : IpcMessage) -> Result[@types.Schema, IpcError] {
  if message.header_type != 1 {
    return Err(UnsupportedMessageType(message.header_type))
  }
  let header = match message_header(message) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let endianness = match lift_fb(header.i16(0, 0)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if endianness != 0 {
    return Err(BigEndianUnsupported)
  }
  let fields = match lift_fb(header.vector(1)) {
    Ok(Some(value)) => value
    Ok(None) => return @types.Schema::new([]).map_err(error => Schema(error))
    Err(error) => return Err(error)
  }
  let decoded : Array[@types.Field] = []
  for i in 0..<fields.len() {
    let field = match lift_fb(fields.table(i)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match decode_field(field) {
      Ok(value) => decoded.push(value)
      Err(error) => return Err(error)
    }
  }
  @types.Schema::new(decoded).map_err(error => Schema(error))
}

///|
priv struct FieldNode {
  length : Int
  null_count : Int
}

///|
priv struct BufferRegion {
  offset : Int
  length : Int
}

///|
fn read_nodes(
  vector : @flatbuffer.Vector,
) -> Result[Array[FieldNode], IpcError] {
  let nodes : Array[FieldNode] = []
  for i in 0..<vector.len() {
    let raw_length = match lift_fb(vector.struct_i64(i, 16, 0)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let raw_null_count = match lift_fb(vector.struct_i64(i, 16, 8)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let length = match checked_int(raw_length) {
      Ok(value) => value
      Err(_) => return Err(InvalidNode(i, raw_length, raw_null_count))
    }
    let null_count = match checked_int(raw_null_count) {
      Ok(value) => value
      Err(_) => return Err(InvalidNode(i, raw_length, raw_null_count))
    }
    if null_count > length {
      return Err(InvalidNode(i, raw_length, raw_null_count))
    }
    nodes.push({ length, null_count, })
  }
  Ok(nodes)
}

///|
fn read_buffers(
  vector : @flatbuffer.Vector,
  body_length : Int,
) -> Result[Array[BufferRegion], IpcError] {
  let buffers : Array[BufferRegion] = []
  for i in 0..<vector.len() {
    let raw_offset = match lift_fb(vector.struct_i64(i, 16, 0)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let raw_length = match lift_fb(vector.struct_i64(i, 16, 8)) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let offset = match checked_int(raw_offset) {
      Ok(value) => value
      Err(_) =>
        return Err(InvalidBuffer(i, raw_offset, raw_length, body_length))
    }
    let length = match checked_int(raw_length) {
      Ok(value) => value
      Err(_) =>
        return Err(InvalidBuffer(i, raw_offset, raw_length, body_length))
    }
    if offset > body_length - length {
      return Err(InvalidBuffer(i, raw_offset, raw_length, body_length))
    }
    buffers.push({ offset, length, })
  }
  Ok(buffers)
}

///|
fn expected_buffer_count(schema : @types.Schema) -> Int {
  let mut count = 0
  for field in schema.fields() {
    count = count +
      (match field.data_type {
        @types.Utf8 | @types.Binary => 3
        _ => 2
      })
  }
  count
}

///|
fn buffer_slice(
  body : Bytes,
  region : BufferRegion,
  index : Int,
) -> Result[Bytes, IpcError] {
  match @flatbuffer.Reader::new(body).slice(region.offset, region.length) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(
        InvalidBuffer(
          index,
          region.offset.to_int64(),
          region.length.to_int64(),
          body.length(),
        ),
      )
  }
}

///|
fn validity_at(
  validity : Bytes,
  row : Int,
  null_count : Int,
  column : Int,
) -> Result[Bool, IpcError] {
  if null_count == 0 && validity.length() == 0 {
    return Ok(true)
  }
  let required = row / 8 + 1
  if validity.length() < required {
    return Err(InvalidValidity(column, required, validity.length()))
  }
  Ok((validity[row / 8].to_int() & (1 << (row % 8))) != 0)
}

///|
fn read_i32_at(
  data : Bytes,
  offset : Int,
  buffer_index : Int,
) -> Result[Int, IpcError] {
  match @flatbuffer.Reader::new(data).read_i32(offset) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(InvalidBuffer(buffer_index, offset.to_int64(), 4L, data.length()))
  }
}

///|
fn read_i64_at(
  data : Bytes,
  offset : Int,
  buffer_index : Int,
) -> Result[Int64, IpcError] {
  match @flatbuffer.Reader::new(data).read_i64(offset) {
    Ok(value) => Ok(value)
    Err(_) =>
      Err(InvalidBuffer(buffer_index, offset.to_int64(), 8L, data.length()))
  }
}

///|
fn decode_int32(
  body : Bytes,
  node : FieldNode,
  validity_region : BufferRegion,
  values_region : BufferRegion,
  column : Int,
  buffer_index : Int,
) -> Result[@record_batch.Column, IpcError] {
  let validity = match buffer_slice(body, validity_region, buffer_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let values = match buffer_slice(body, values_region, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if node.length > values.length() / 4 {
    return Err(
      InvalidBuffer(
        buffer_index + 1,
        values_region.offset.to_int64(),
        values_region.length.to_int64(),
        body.length(),
      ),
    )
  }
  let decoded : Array[Int?] = []
  let mut observed_nulls = 0
  for row in 0..<node.length {
    let valid = match validity_at(validity, row, node.null_count, column) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if valid {
      match read_i32_at(values, row * 4, buffer_index + 1) {
        Ok(value) => decoded.push(Some(value))
        Err(error) => return Err(error)
      }
    } else {
      decoded.push(None)
      observed_nulls = observed_nulls + 1
    }
  }
  if observed_nulls != node.null_count {
    return Err(
      InvalidNode(column, node.length.to_int64(), node.null_count.to_int64()),
    )
  }
  Ok(@record_batch.Int32(@array.Int32Array::from_options(decoded)))
}

///|
fn decode_int64(
  body : Bytes,
  node : FieldNode,
  validity_region : BufferRegion,
  values_region : BufferRegion,
  column : Int,
  buffer_index : Int,
) -> Result[@record_batch.Column, IpcError] {
  let validity = match buffer_slice(body, validity_region, buffer_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let values = match buffer_slice(body, values_region, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if node.length > values.length() / 8 {
    return Err(
      InvalidBuffer(
        buffer_index + 1,
        values_region.offset.to_int64(),
        values_region.length.to_int64(),
        body.length(),
      ),
    )
  }
  let decoded : Array[Int64?] = []
  let mut observed_nulls = 0
  for row in 0..<node.length {
    let valid = match validity_at(validity, row, node.null_count, column) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if valid {
      match read_i64_at(values, row * 8, buffer_index + 1) {
        Ok(value) => decoded.push(Some(value))
        Err(error) => return Err(error)
      }
    } else {
      decoded.push(None)
      observed_nulls = observed_nulls + 1
    }
  }
  if observed_nulls != node.null_count {
    return Err(
      InvalidNode(column, node.length.to_int64(), node.null_count.to_int64()),
    )
  }
  Ok(@record_batch.Int64(@array.Int64Array::from_options(decoded)))
}

///|
fn decode_bool(
  body : Bytes,
  node : FieldNode,
  validity_region : BufferRegion,
  values_region : BufferRegion,
  column : Int,
  buffer_index : Int,
) -> Result[@record_batch.Column, IpcError] {
  let validity = match buffer_slice(body, validity_region, buffer_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let values = match buffer_slice(body, values_region, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let required = node.length / 8 + (if node.length % 8 == 0 { 0 } else { 1 })
  if values.length() < required {
    return Err(
      InvalidBuffer(
        buffer_index + 1,
        values_region.offset.to_int64(),
        values_region.length.to_int64(),
        body.length(),
      ),
    )
  }
  let decoded : Array[Bool?] = []
  let mut observed_nulls = 0
  for row in 0..<node.length {
    let valid = match validity_at(validity, row, node.null_count, column) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if valid {
      decoded.push(Some((values[row / 8].to_int() & (1 << (row % 8))) != 0))
    } else {
      decoded.push(None)
      observed_nulls = observed_nulls + 1
    }
  }
  if observed_nulls != node.null_count {
    return Err(
      InvalidNode(column, node.length.to_int64(), node.null_count.to_int64()),
    )
  }
  Ok(@record_batch.Bool(@array.BoolArray::from_options(decoded)))
}

///|
fn decode_float64(
  body : Bytes,
  node : FieldNode,
  validity_region : BufferRegion,
  values_region : BufferRegion,
  column : Int,
  buffer_index : Int,
) -> Result[@record_batch.Column, IpcError] {
  let validity = match buffer_slice(body, validity_region, buffer_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let values = match buffer_slice(body, values_region, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if node.length > values.length() / 8 {
    return Err(
      InvalidBuffer(
        buffer_index + 1,
        values_region.offset.to_int64(),
        values_region.length.to_int64(),
        body.length(),
      ),
    )
  }
  let value_reader = @flatbuffer.Reader::new(values)
  let decoded : Array[Double?] = []
  let mut observed_nulls = 0
  for row in 0..<node.length {
    let valid = match validity_at(validity, row, node.null_count, column) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if valid {
      match value_reader.read_u64(row * 8) {
        Ok(value) => decoded.push(Some(value.reinterpret_as_double()))
        Err(error) => return Err(Flatbuffer(error))
      }
    } else {
      decoded.push(None)
      observed_nulls = observed_nulls + 1
    }
  }
  if observed_nulls != node.null_count {
    return Err(
      InvalidNode(column, node.length.to_int64(), node.null_count.to_int64()),
    )
  }
  Ok(@record_batch.Float64(@array.Float64Array::from_options(decoded)))
}

///|
fn decode_utf8_value(
  data : Bytes,
  start : Int,
  end : Int,
  column : Int,
) -> Result[String, IpcError] {
  if start < 0 || end < start || end > data.length() {
    return Err(InvalidOffsets(column, start, end))
  }
  guard data.get_view(start~, end~) is Some(view) else {
    return Err(InvalidOffsets(column, start, end))
  }
  let raw = Bytes::from_array(view.to_array())
  let decoded = @utf8.decode_lossy(raw)
  if @utf8.encode(decoded) != raw {
    Err(InvalidUtf8(start, end - start))
  } else {
    Ok(decoded)
  }
}

///|
fn decode_binary_value(
  data : Bytes,
  start : Int,
  end : Int,
  column : Int,
) -> Result[Bytes, IpcError] {
  if start < 0 || end < start || end > data.length() {
    return Err(InvalidOffsets(column, start, end))
  }
  guard data.get_view(start~, end~) is Some(view) else {
    return Err(InvalidOffsets(column, start, end))
  }
  Ok(view.to_owned())
}

///|
fn decode_binary(
  body : Bytes,
  node : FieldNode,
  validity_region : BufferRegion,
  offsets_region : BufferRegion,
  data_region : BufferRegion,
  column : Int,
  buffer_index : Int,
) -> Result[@record_batch.Column, IpcError] {
  let validity = match buffer_slice(body, validity_region, buffer_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let offsets = match buffer_slice(body, offsets_region, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let data = match buffer_slice(body, data_region, buffer_index + 2) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if offsets.length() < 4 || node.length > offsets.length() / 4 - 1 {
    return Err(
      InvalidBuffer(
        buffer_index + 1,
        offsets_region.offset.to_int64(),
        offsets_region.length.to_int64(),
        body.length(),
      ),
    )
  }
  let first = match read_i32_at(offsets, 0, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if first != 0 {
    return Err(InvalidOffsets(column, 0, first))
  }
  let decoded : Array[Bytes?] = []
  let mut previous = first
  let mut observed_nulls = 0
  for row in 0..<node.length {
    let end = match read_i32_at(offsets, (row + 1) * 4, buffer_index + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if end < previous || end > data.length() {
      return Err(InvalidOffsets(column, previous, end))
    }
    let valid = match validity_at(validity, row, node.null_count, column) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if valid {
      match decode_binary_value(data, previous, end, column) {
        Ok(value) => decoded.push(Some(value))
        Err(error) => return Err(error)
      }
    } else {
      decoded.push(None)
      observed_nulls = observed_nulls + 1
    }
    previous = end
  }
  if observed_nulls != node.null_count {
    return Err(
      InvalidNode(column, node.length.to_int64(), node.null_count.to_int64()),
    )
  }
  Ok(@record_batch.Binary(@array.BinaryArray::from_options(decoded)))
}

///|
fn decode_utf8(
  body : Bytes,
  node : FieldNode,
  validity_region : BufferRegion,
  offsets_region : BufferRegion,
  data_region : BufferRegion,
  column : Int,
  buffer_index : Int,
) -> Result[@record_batch.Column, IpcError] {
  let validity = match buffer_slice(body, validity_region, buffer_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let offsets = match buffer_slice(body, offsets_region, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let data = match buffer_slice(body, data_region, buffer_index + 2) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if offsets.length() < 4 || node.length > offsets.length() / 4 - 1 {
    return Err(
      InvalidBuffer(
        buffer_index + 1,
        offsets_region.offset.to_int64(),
        offsets_region.length.to_int64(),
        body.length(),
      ),
    )
  }
  let first = match read_i32_at(offsets, 0, buffer_index + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if first != 0 {
    return Err(InvalidOffsets(column, 0, first))
  }
  let decoded : Array[String?] = []
  let mut previous = first
  let mut observed_nulls = 0
  for row in 0..<node.length {
    let end = match read_i32_at(offsets, (row + 1) * 4, buffer_index + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if end < previous || end > data.length() {
      return Err(InvalidOffsets(column, previous, end))
    }
    let valid = match validity_at(validity, row, node.null_count, column) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if valid {
      match decode_utf8_value(data, previous, end, column) {
        Ok(value) => decoded.push(Some(value))
        Err(error) => return Err(error)
      }
    } else {
      decoded.push(None)
      observed_nulls = observed_nulls + 1
    }
    previous = end
  }
  if observed_nulls != node.null_count {
    return Err(
      InvalidNode(column, node.length.to_int64(), node.null_count.to_int64()),
    )
  }
  Ok(@record_batch.Utf8(@array.Utf8Array::from_options(decoded)))
}

///|
fn decode_record_batch(
  message : IpcMessage,
  schema : @types.Schema,
) -> Result[@record_batch.RecordBatch, IpcError] {
  if message.header_type != 3 {
    return Err(UnsupportedMessageType(message.header_type))
  }
  let header = match message_header(message) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let raw_row_count = match lift_fb(header.i64(0, 0L)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let row_count = match checked_int(raw_row_count) {
    Ok(value) => value
    Err(_) => return Err(InvalidRecordLength(raw_row_count))
  }
  let node_vector = match lift_fb(header.vector(1)) {
    Ok(Some(value)) => value
    Ok(None) => return Err(InvalidNodeCount(0, schema.len()))
    Err(error) => return Err(error)
  }
  let buffer_vector = match lift_fb(header.vector(2)) {
    Ok(Some(value)) => value
    Ok(None) => return Err(InvalidBufferCount(0, expected_buffer_count(schema)))
    Err(error) => return Err(error)
  }
  if node_vector.len() != schema.len() {
    return Err(InvalidNodeCount(node_vector.len(), schema.len()))
  }
  let expected_buffers = expected_buffer_count(schema)
  if buffer_vector.len() != expected_buffers {
    return Err(InvalidBufferCount(buffer_vector.len(), expected_buffers))
  }
  let nodes = match read_nodes(node_vector) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let buffers = match read_buffers(buffer_vector, message.body.length()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let columns : Array[@record_batch.Column] = []
  let mut buffer_index = 0
  for column_index in 0..<schema.len() {
    let field = schema.field(column_index).unwrap()
    let node = nodes[column_index]
    if node.length != row_count {
      return Err(
        InvalidNode(
          column_index,
          node.length.to_int64(),
          node.null_count.to_int64(),
        ),
      )
    }
    let decoded = match field.data_type {
      @types.Int32 =>
        decode_int32(
          message.body,
          node,
          buffers[buffer_index],
          buffers[buffer_index + 1],
          column_index,
          buffer_index,
        )
      @types.Int64 =>
        decode_int64(
          message.body,
          node,
          buffers[buffer_index],
          buffers[buffer_index + 1],
          column_index,
          buffer_index,
        )
      @types.Boolean =>
        decode_bool(
          message.body,
          node,
          buffers[buffer_index],
          buffers[buffer_index + 1],
          column_index,
          buffer_index,
        )
      @types.Float64 =>
        decode_float64(
          message.body,
          node,
          buffers[buffer_index],
          buffers[buffer_index + 1],
          column_index,
          buffer_index,
        )
      @types.Utf8 =>
        decode_utf8(
          message.body,
          node,
          buffers[buffer_index],
          buffers[buffer_index + 1],
          buffers[buffer_index + 2],
          column_index,
          buffer_index,
        )
      @types.Binary =>
        decode_binary(
          message.body,
          node,
          buffers[buffer_index],
          buffers[buffer_index + 1],
          buffers[buffer_index + 2],
          column_index,
          buffer_index,
        )
    }
    match decoded {
      Ok(value) => columns.push(value)
      Err(error) => return Err(error)
    }
    buffer_index = buffer_index +
      (match field.data_type {
        @types.Utf8 | @types.Binary => 3
        _ => 2
      })
  }
  @record_batch.RecordBatch::new(schema, columns).map_err(error => {
    RecordBatch(error)
  })
}

///|
pub struct IpcStream {
  schema : @types.Schema
  batches : Array[@record_batch.RecordBatch]
}

///|
pub fn IpcStream::schema(self : IpcStream) -> @types.Schema {
  self.schema
}

///|
pub fn IpcStream::batch_count(self : IpcStream) -> Int {
  self.batches.length()
}

///|
pub fn IpcStream::batch(
  self : IpcStream,
  index : Int,
) -> @record_batch.RecordBatch? {
  self.batches.get(index)
}

///|
pub fn IpcStream::batches(self : IpcStream) -> Array[@record_batch.RecordBatch] {
  self.batches.copy()
}

///|
/// Decode a complete Arrow IPC stream containing one schema followed by zero
/// or more record batches. Dictionary and nested messages are rejected with a
/// precise unsupported-feature error.
pub fn read_stream(data : Bytes) -> Result[IpcStream, IpcError] {
  let messages = match parse_messages(data) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if messages.is_empty() || messages[0].header_type != 1 {
    return Err(MissingSchema)
  }
  let schema = match decode_schema(messages[0]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let batches : Array[@record_batch.RecordBatch] = []
  for i in 1..<messages.length() {
    let message = messages[i]
    if message.header_type != 3 {
      return Err(UnsupportedMessageType(message.header_type))
    }
    match decode_record_batch(message, schema) {
      Ok(value) => batches.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok({ schema, batches, })
}
