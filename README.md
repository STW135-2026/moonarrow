# MoonQuery

[![CI](https://github.com/STW135-2026/moonquery/actions/workflows/ci.yml/badge.svg)](https://github.com/STW135-2026/moonquery/actions/workflows/ci.yml)

**面向 MoonBit 与 WebAssembly 的嵌入式列式查询引擎。**

MoonQuery 在 [`shunge/arrow`](https://mooncakes.io/docs/shunge/arrow) 提供的
Arrow 数据结构和 IPC 读写能力之上，增加查询表达式、逻辑计划和数据变换能力。
本项目不实现另一套 Arrow IPC、FlatBuffers、位图或 RecordBatch 容器。

## 已实现

- 可组合的类型化谓词，以及 SQL 风格三值逻辑。
- 延迟构建、显式执行并可 `explain` 的查询计划。
- Filter、Project、Limit 与稳定排序（null 始终置后）。
- UTF-8 分组、Int32 `SUM` 和行数 `COUNT`。
- Boolean、Int32、Int64、UTF-8 键的确定性内连接；null 键不匹配。
- 结构化查询错误和每个算子输出的 Arrow RecordBatch 重新校验。
- 通过 `shunge/arrow` 完成查询结果的 Arrow IPC 输出与回读。
- Native、JavaScript、Wasm、Wasm-GC 四后端测试。

## 三分钟验证

```sh
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target native
```

演示会打印以下逻辑计划，并执行真实查询：

```text
0: Scan ArrowRecordBatch(rows=5, columns=5)
1: Filter (col("units") > 2) AND (col("active") IS TRUE)
2: GroupBy region; SUM(revenue) AS revenue_sum; COUNT(*) AS orders
3: Sort revenue_sum DESC NULLS LAST
4: Limit 3
```

最后由 `shunge/arrow` 把结果写成 Arrow IPC Stream 并重新读取，形成端到端验证。

## 使用示例

```mbt
let result = @query.Query::scan(batch)
  .filter(
    @query.Int32GreaterThan("units", 2).and_also(
      @query.BoolIsTrue("active"),
    ),
  )
  .group_by_utf8_sum_int32(
    "region",
    "revenue",
    sum_alias="revenue_sum",
    count_alias="orders",
  )
  .sort_by("revenue_sum", descending=true)
  .limit(10)
  .execute()
  .unwrap()
```

## 与 `shunge/arrow` 的边界

| 能力 | `shunge/arrow` | MoonQuery |
| --- | --- | --- |
| Arrow Schema、Column、RecordBatch | 提供 | 直接使用 |
| IPC Stream/File 读写 | 提供 | 直接调用 |
| 格式校验与解析预算 | 提供 | 不重复实现 |
| 查询谓词和三值逻辑 | 不负责 | 提供 |
| Filter/Project/Limit/Sort | 不负责 | 提供 |
| Group By 和聚合 | 不负责 | 提供 |
| Join | 不负责 | 提供 |
| 逻辑计划与 Explain | 不负责 | 提供 |

更完整的代码级证据见[差异化说明](docs/DIFFERENTIATION.zh-CN.md)。

## 当前边界

- 当前排序使用稳定插入排序，内连接使用确定性嵌套循环；MVP 先验证语义正确性，
  尚未声称适合大规模数据。
- 分组聚合当前为 UTF-8 key + Int32 value 的 `SUM`/`COUNT`。
- 当前未实现 SQL 文本解析、查询优化器、并行执行、磁盘溢写或流式增量执行。
- Arrow 类型和 IPC 支持范围由锁定的 `shunge/arrow@0.1.0` 决定。

## 文档

- [项目申报书](docs/PROPOSAL.zh-CN.md)
- [差异化与互补边界](docs/DIFFERENTIATION.zh-CN.md)
- [架构](docs/ARCHITECTURE.md)
- [验收清单](docs/MVP-CHECKLIST.zh-CN.md)
- [演示脚本](docs/DEMO.zh-CN.md)
- [路线图](docs/ROADMAP.md)

## 许可证

Apache-2.0。`shunge/arrow` 是独立的 MIT 许可依赖，来源和职责在文档中明确标注。
