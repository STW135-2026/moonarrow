# MoonQuery architecture

MoonQuery has one dependency direction:

```text
Arrow IPC bytes
      │
      ▼
shunge/arrow  ── Schema / Column / RecordBatch / IPC validation
      │
      ▼
MoonQuery     ── Predicate / QueryStep / Query / execution
      │
      ▼
shunge/arrow  ── validated RecordBatch / optional IPC output
```

The project intentionally contains no Arrow binary-format layer.

## Logical plan

`Query::scan` stores an Arrow `RecordBatch`. Builder methods append immutable
logical steps without executing them. `Query::explain` renders the same ordered
steps that `Query::execute` evaluates.

Implemented steps:

- `Filter(Predicate)`
- `Project(Array[String])`
- `Limit(Int)`
- `Sort(String, Bool)`
- `GroupUtf8SumInt32(...)`
- `InnerJoin(RecordBatch, left_key, right_key)`

## Null semantics

Predicates return `Bool?`. `AND`, `OR`, and `NOT` use SQL-style three-valued
logic. Filter keeps only `Some(true)`; both `Some(false)` and `None` are
discarded. Grouping keeps a null-key group, SUM ignores null inputs and returns
null for an all-null group, and COUNT counts rows. Join never matches null keys.

## Validation boundary

Every operator constructs output columns compatible with `shunge/arrow` and
then calls `RecordBatch::new`. A malformed result becomes `InvalidBatch`; it is
never returned as a successful query result.

## Current algorithm choices

Correctness and deterministic multi-target behavior are the MVP priorities.
Sort is stable insertion sort, grouping uses stable linear group lookup, and
inner join uses nested loops. These choices are stated rather than hidden.
Hash-based operators and benchmarks belong to the next milestone.
