# Changelog

All notable changes to MoonArrow are recorded here.

## Unreleased

### Added

- Nullable `Int64Array` and variable-width `BinaryArray` using Arrow-compatible
  physical layouts.
- Int64 and Binary filtering across compute, RecordBatch, and DataFrame layers.
- Arrow IPC decoding for signed 64-bit integers and binary values.
- PyArrow 25 interoperability coverage for six logical types.
- Row previews in the native IPC inspector.
- Reproducible MVP acceptance checklist and end-to-end CI smoke demos.
- Negative interoperability tests for truncated streams and invalid UTF-8.

### Changed

- Pin fixture generation and documentation to PyArrow 25.0.1.
- Clarify that IPC reading materializes MoonBit arrays and that writing and
  zero-copy C Data Interface support are future work.

## 0.1.0 - 2026-09-16

### Added

- Arrow-style Schema, Field, bitmap, nullable arrays, and RecordBatch types.
- Columnar filter, take, comparison, and aggregation kernels.
- Eager DataFrame projection, filtering, limiting, sum, and mean operations.
- Bounds-checked FlatBuffers metadata reader and Arrow IPC Stream decoder.
- PyArrow-generated interoperability fixture.
- Native CLI demos and Native/JS/Wasm/WasmGC test matrix.
