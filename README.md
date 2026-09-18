# MoonSentinel

[![CI](https://github.com/STW135-2026/moonsentinel/actions/workflows/ci.yml/badge.svg)](https://github.com/STW135-2026/moonsentinel/actions/workflows/ci.yml)

MoonSentinel 是面向 MoonBit 的 Arrow 数据发布门禁。它在数据进入分析、浏览器应用或 AI 工作流前执行确定性的质量规则，将合法行、隔离行和结构化诊断分别输出为 Arrow RecordBatch，并可在放行前脱敏 UTF-8 敏感列。

项目直接使用 [`shunge/arrow@0.1.0`](https://mooncakes.io/docs/shunge/arrow@0.1.0) 的 Schema、Column、RecordBatch 和 IPC 能力，不实现 DataFrame、查询引擎、Arrow IPC、JSON Schema 或 Schema 版本管理。

## 已实现

- 8 类声明式规则：必需列、非空、Int32/Int64 范围、非空字符串、字符串允许列表、字符串唯一性和 Int32 跨字段顺序。
- `Error` 与 `Warning` 两级结果。错误隔离对应行；数据集级错误隔离整个批次；警告只记录，不阻断放行。
- 确定性执行顺序和有上限的诊断收集。即使诊断被截断，错误数和警告数仍保持准确。
- 一次 `release` 生成 approved、quarantine 和 findings 三个 Arrow RecordBatch。
- 仅对 approved 数据应用 UTF-8 替换脱敏，quarantine 保留原值用于受控排查。
- 合同、输入批次和脱敏策略的结构化错误处理。
- Native、JavaScript、Wasm、Wasm-GC 四后端检查与测试。

## 三分钟验证

```sh
moon update
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target native --deny-warn
```

当前演示使用 4 行客户导出数据，运行唯一性、年龄范围、国家允许列表、订单上下界和邮件完整性规则。实际输出为：

```text
MoonSentinel release gate
customer-export-v1: FAIL; rows=4; accepted=1; quarantined=3; errors=7; warnings=1; findings_shown=8; truncated=false
approved rows: 1
quarantined rows: 3
diagnostic rows: 8
approved email: [REDACTED]
```

## 使用示例

```mbt
let contract = @gate.Contract::new("customer-export-v1", [
  @gate.RequiredColumn(
    "schema.customer_id",
    "customer_id",
    @arrow.Utf8,
    @gate.Error,
  ),
  @gate.NotNull(
    "quality.customer_id.required",
    "customer_id",
    @gate.Error,
  ),
  @gate.Utf8Unique(
    "quality.customer_id.unique",
    "customer_id",
    @gate.Error,
  ),
  @gate.Int32Range(
    "quality.age.range",
    "age",
    Some(0),
    Some(120),
    @gate.Error,
  ),
]).unwrap()

let bundle = contract.release(
  batch,
  redactions=[@gate.ReplaceUtf8("email", "[REDACTED]")],
).unwrap()

let approved = bundle.approved()
let quarantine = bundle.quarantine()
let findings = bundle.findings()
```

findings 批次包含 `rule_id`、`severity`、`row`、`column`、`code` 和 `message`，可直接写入 Arrow IPC、交给审计系统或在前端展示。

## 与现有项目的边界

| 项目 | 已有职责 | MoonSentinel 的职责 |
| --- | --- | --- |
| [`shunge/arrow`](https://mooncakes.io/docs/shunge/arrow@0.1.0) | Arrow 数据结构、IPC Stream/File 和互操作 | 消费 RecordBatch，执行发布门禁并产出新的 RecordBatch |
| [`MoonFrame`](https://github.com/ihb2032/MoonFrame) | DataFrame、表达式、过滤、排序、分组、连接和惰性查询 | 不提供查询算子；负责质量判定、隔离、诊断和脱敏 |
| [`moon-data-contract`](https://mooncakes.io/docs/lyjttio/moon-data-contract@0.2.1) | Schema 治理、版本演进、兼容性和迁移计划 | 不管理 Schema 版本；检查批次中的实际行并执行放行决策 |
| [`moonbit-jsonschema`](https://mooncakes.io/docs/Xu107-hhh/moonbit-jsonschema) | JSON Schema 验证 | 不解析 JSON Schema；面向 Arrow 列和行 |
| [`MoonJQ`](https://github.com/moonbit-community/moonbit-jq) | JSON 查询解释器 | 不查询 JSON；输出 Arrow 原生审计结果 |

旧版 MoonQuery 查询引擎因与 MoonFrame 的功能范围重合，已经从当前代码树移除。Git 历史完整保留这次边界调整。

## 当前边界

- 当前规则以可审计的基础约束为主，还没有正则表达式、条件规则或跨批次状态。
- `Utf8Unique` 在单个 RecordBatch 内检查，采用确定性双循环，MVP 优先保证语义和可复现性。
- 脱敏目前提供 UTF-8 固定替换；哈希、部分保留和密钥托管不在当前版本中。
- 数据读取和写出由 `shunge/arrow` 负责；MoonSentinel 不重复实现 IPC。

## 文档

- [项目申报书](docs/PROPOSAL.zh-CN.md)
- [差异化核查](docs/DIFFERENTIATION.zh-CN.md)
- [技术架构](docs/ARCHITECTURE.md)
- [演示步骤](docs/DEMO.zh-CN.md)

## 许可证

Apache-2.0。`shunge/arrow` 是独立的 MIT 许可依赖。
