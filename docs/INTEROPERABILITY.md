# Integration contract with `shunge/arrow`

MoonQuery depends on `shunge/arrow@0.1.0` for Arrow types and IPC. It does not
copy or wrap the binary format implementation.

## Input contract

The query source is a validated `@arrow.RecordBatch`. Applications may create
the batch directly or obtain it from `@arrow.read_stream`, `@arrow.read_file`,
`StreamReader`, or `FileReader`.

## Output contract

Every successful query returns another validated `@arrow.RecordBatch`. The
caller can immediately pass its schema and batch to `@arrow.write_stream` or
`@arrow.write_file`.

## Executable proof

The test named `Arrow IPC roundtrip is supplied by shunge arrow` performs:

1. query an Arrow batch;
2. write the result with `@arrow.write_stream`;
3. read it with `@arrow.read_stream`;
4. verify row count and values.

This test runs on Native, JavaScript, Wasm, and Wasm-GC. Format compatibility
claims remain the responsibility of the dependency; MoonQuery tests only that
its query results satisfy the public Arrow API contract.
