# Changelog

## 0.2.0 — MoonQuery pivot

### Added

- Typed composable predicates with three-valued null semantics.
- Lazy logical query plans with stable explain output.
- Filter, project, limit and nulls-last stable sort.
- UTF-8 group by with nullable Int32 SUM and row COUNT.
- Deterministic inner joins for Boolean, Int32, Int64 and UTF-8 keys.
- Structured query errors and four-target tests.
- End-to-end Arrow IPC handoff through `shunge/arrow@0.1.0`.

### Changed

- Renamed the project from MoonArrow to MoonQuery.
- Repositioned the project as a query execution layer above existing Arrow
  infrastructure.

### Removed

- The duplicate IPC, FlatBuffers, bitmap, array and RecordBatch implementations.
- The PyArrow fixture generator and IPC inspector, which belonged to the old
  overlapping scope.

Historical releases remain available through Git history.
