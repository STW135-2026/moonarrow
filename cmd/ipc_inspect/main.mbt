///|
async fn main {
  let matches = @argparse.Command(
    "moonarrow-inspect",
    about="Inspect an Apache Arrow IPC stream",
    positionals=[
      PositionArg("file", about="Arrow IPC stream file", default_values=[
        "fixtures/pyarrow-basic.arrows",
      ]),
    ],
  ).parse()
  let path = match matches.values {
    { "file": [path], .. } => path
    _ => "fixtures/pyarrow-basic.arrows"
  }
  let bytes = @fs.read_file(path).binary()
  match @ipc.read_stream(bytes) {
    Err(error) => println("invalid Arrow IPC stream: \{Repr(error)}")
    Ok(stream) => {
      let schema = stream.schema()
      println("MoonArrow IPC inspector")
      println("file: \{path}")
      println("fields: \{schema.len()}")
      for field in schema.fields() {
        let nullable = if field.nullable { "nullable" } else { "required" }
        println("  \{field.name}: \{field.data_type.name()} (\{nullable})")
      }
      println("record batches: \{stream.batch_count()}")
      for index in 0..<stream.batch_count() {
        let batch = stream.batch(index).unwrap()
        println("  batch \{index}: \{batch.row_count()} rows")
      }
    }
  }
}
