# MoonQuery roadmap

## M1 — Distinct query MVP

- [x] Depend on `shunge/arrow` instead of implementing Arrow IPC.
- [x] Typed predicates with three-valued null semantics.
- [x] Lazy logical plan and explain output.
- [x] Filter, project, limit and stable sort.
- [x] UTF-8 group by with Int32 SUM and row COUNT.
- [x] Deterministic inner join for common key types.
- [x] Four-target tests and Arrow IPC handoff demo.

## M2 — General expression engine

- [ ] Scalar expression tree for arithmetic and aliases.
- [ ] Comparisons for more numeric types.
- [ ] Generic aggregate definitions and multiple aggregate expressions.
- [ ] Schema inference before execution.

## M3 — Performance

- [ ] Hash aggregation with deterministic output ordering.
- [ ] Hash join with build/probe-side selection.
- [ ] Chunked execution and configurable batch size.
- [ ] Reproducible benchmarks with dataset, hardware and toolchain recorded.

## M4 — Optimizer and applications

- [ ] Predicate and projection pushdown inside MoonQuery plans.
- [ ] Constant folding and redundant-step elimination.
- [ ] Browser/Wasm offline data explorer using the same query core.
- [ ] One documented downstream integration.

Arrow format coverage remains outside this roadmap and follows the capabilities
of `shunge/arrow`.
