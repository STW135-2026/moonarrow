# Roadmap

## M1 — Columnar memory core

- [x] Logical schema and fields
- [x] LSB-first validity bitmap
- [x] Nullable Int32, Int64, Float64, Boolean, UTF-8, and Binary arrays
- [x] Record batch validation
- [x] Filter, take, comparison, and aggregation kernels
- [x] Multi-target CI and runnable example

## M2 — Arrow IPC stream

- [x] Buffer alignment and little-endian helpers
- [x] Bounds-checked FlatBuffers metadata reader
- [x] Schema and record-batch message reader
- [x] IPC stream reader
- [x] PyArrow interoperability fixture and test
- [ ] FlatBuffers metadata writer
- [ ] IPC stream writer and bidirectional interoperability test

## M3 — Type coverage

- [x] Int64 and Binary
- [ ] Int8/16 and unsigned integers
- [ ] Float32 and LargeUtf8
- [ ] List, Struct and Dictionary arrays
- [ ] Timestamp, Date and Duration

## M4 — Compute and tabular API

- [ ] Vectorized arithmetic and boolean kernels
- [ ] Sort, hash aggregate and join
- [ ] Chunked arrays and tables
- [ ] Expression AST and lazy query plan
- [x] Eager projection, Boolean filtering, integer predicates, limit, and basic
      aggregation facade

## M5 — Ecosystem integration

- [ ] CSV/JSONL adapters
- [ ] JavaScript and browser package
- [ ] Parquet reader
- [ ] Benchmarks against reference implementations
