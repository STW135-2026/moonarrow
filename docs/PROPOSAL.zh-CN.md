# MoonSentinel 项目申报书

## 一 项目基本信息

- 项目名称：MoonSentinel
- 项目副标题：面向 Arrow 数据的质量与隐私发布门禁
- 项目负责人：苏天伟
- 开源许可证：Apache-2.0
- 代码仓库：<https://github.com/STW135-2026/moonsentinel>
- 底层依赖：`shunge/arrow@0.1.0`，MIT 许可证

## 二 项目简介

MoonSentinel 是使用 MoonBit 编写的 Arrow 数据发布门禁。系统接收一个 Arrow RecordBatch 和一组声明式规则，逐行检查质量问题，区分阻断错误与非阻断警告，再生成获准数据、隔离数据和结构化诊断三个 RecordBatch。获准数据还可在交付前替换敏感 UTF-8 字段。

该项目解决的是数据已经能够交换，但尚不能安全发布的问题。它不提供过滤、排序、分组或连接等通用查询能力，也不实现 Arrow IPC、JSON Schema、Schema 版本治理或迁移计划。

## 三 问题和实际价值

数据库、Python 数据工具和浏览器应用可以使用 Arrow 交换列式数据，但格式正确并不代表内容可直接发布。真实批次可能包含重复标识、越界年龄、无效枚举、颠倒的上下界、缺失联系方式或未脱敏字段。若每个应用分别编写临时检查逻辑，规则、错误格式和处置方式会逐渐不一致。

MoonSentinel 把这一步收敛为可测试的发布门禁，适用于以下场景：

1. 数据产品发布。导出数据只有通过质量规则后才能进入报表、下载文件或下游 API。
2. 浏览器与边缘应用。MoonBit/Wasm 在本地检查 Arrow 数据，错误行不进入后续计算。
3. AI 数据准备。进入模型或检索流程前，先隔离错误行并替换敏感文本字段。
4. 数据管道排错。诊断结果仍是 Arrow RecordBatch，可写入 IPC、存档或展示。

## 四 已完成成果

当前代码已经实现并通过自动测试：

- 8 类规则：必需列、非空、Int32 范围、Int64 范围、非空字符串、字符串允许列表、字符串唯一性和 Int32 跨字段顺序。
- `Error` 与 `Warning` 两级严重度。错误隔离行，警告只进入报告。
- 缺失列和类型错误作为数据集级问题处理；数据集级错误阻止整个批次放行。
- 规则按声明顺序执行，行按源顺序检查，结果可复现。
- 诊断数量可设上限；即使只保留部分诊断，总错误数和警告数仍准确。
- `release` 同时生成 approved、quarantine 和 findings 三个 Arrow RecordBatch。
- UTF-8 固定替换只应用于 approved，quarantine 保留原值供受控排查。
- 合同定义、输入批次和脱敏配置均有结构化错误。
- 诊断批次可由 `shunge/arrow` 写入 IPC Stream 并重新读取。
- 7 项测试在 Native、JavaScript、Wasm、Wasm-GC 四个目标上全部通过。

## 五 核心流程

MoonSentinel 的处理顺序如下：

1. 校验 Arrow RecordBatch 自身的字段数量、列长度、类型和 nullability。
2. 校验合同名称、规则编号、范围端点、允许列表和规则编号唯一性。
3. 按规则声明顺序检查 Schema 和行值，并累计错误和警告。
4. 错误对应的行进入 quarantine；没有错误的行进入 approved。
5. 只对 approved 执行配置的字段替换脱敏。
6. 将诊断转换为包含六个字段的 Arrow RecordBatch。

findings 的字段为 `rule_id`、`severity`、`row`、`column`、`code` 和 `message`。其中 `row` 为空表示缺失列或类型不符等数据集级问题。

## 六 示例结果

仓库演示构造 4 行客户导出数据，并检查客户编号唯一性、年龄范围、国家允许列表、订单上下界和邮件完整性。实际运行结果为：

```text
customer-export-v1: FAIL; rows=4; accepted=1; quarantined=3; errors=7; warnings=1; findings_shown=8; truncated=false
approved rows: 1
quarantined rows: 3
diagnostic rows: 8
approved email: [REDACTED]
```

运行命令：

```sh
moon update
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target native --deny-warn
```

## 七 与现有项目的差异

| 对比项目 | 已有能力 | MoonSentinel 的边界 |
| --- | --- | --- |
| `shunge/arrow` | Arrow 数据结构、IPC Stream/File、互操作 | 使用其 RecordBatch；新增发布判定、隔离、诊断和脱敏 |
| MoonFrame | DataFrame、表达式、查询、分组、连接和惰性执行 | 不做查询；处理数据质量和发布处置 |
| `moon-data-contract` | Schema 治理、演进、兼容性、迁移和发布规则 | 不管理 Schema 版本；检查实际批次内容并拆分行 |
| `moonbit-jsonschema` | 按 JSON Schema 验证 JSON | 不解析 JSON Schema；直接处理 Arrow 列 |
| MoonJQ | JSON 查询语言和解释执行 | 不提供查询语言；诊断和输出均为 Arrow 原生结构 |

初版 MoonQuery 曾实现过滤、排序、分组、连接和逻辑计划。核查 MoonFrame 后确认该方向重合度过高，因此当前代码树已移除整个查询包，转为独立的运行时发布门禁。该调整保留在 Git 历史中，便于审查。

## 八 创新和应用特点

1. 门禁直接接收和返回 Arrow RecordBatch，获准数据、隔离数据和诊断数据使用同一种交换格式。
2. 质量判定与处置合并在一次调用中，调用方无需再次根据错误列表手工筛行。
3. 诊断收集有明确上限，但统计不丢失，避免异常批次产生无界内存开销。
4. 脱敏只作用于获准数据，既防止敏感数据进入下游，也保留隔离数据的排错价值。
5. 数据集级错误和行级错误使用同一报告模型，可统一存档和展示。

## 九 原创和依赖边界

本仓库实现合同校验、规则执行、严重度语义、诊断上限、行隔离、脱敏策略、Arrow 诊断输出、测试和演示。Arrow Schema、Column、RecordBatch 以及 IPC 编解码来自公开依赖 `shunge/arrow`，不作为本项目原创成果申报。

当前生产代码仅位于 `src/gate`，没有 DataFrame、查询计划、IPC、FlatBuffers、位图、JSON Schema 或 Schema 迁移实现。旧版探索代码只存在于 Git 历史，不属于当前交付物。

## 十 当前限制

- 规则面向单个 RecordBatch，尚未提供跨批次唯一性和时间窗口状态。
- `Utf8Unique` 使用确定性双循环，适合 MVP 和中小批次，尚未进行哈希优化。
- 字符串规则尚未提供正则表达式和长度范围。
- 脱敏目前是固定字符串替换，尚未提供哈希、部分保留或外部密钥服务。
- 输入输出格式仍由 `shunge/arrow@0.1.0` 的类型和 IPC 支持范围决定。

## 十一 后续路线

1. 增加字符串长度、模式、数值集合和条件规则。
2. 为唯一性规则增加确定性哈希索引，并建立不同批次规模的基准。
3. 增加电子邮件、手机号等可组合脱敏策略，同时避免在诊断文本中泄露原值。
4. 支持多批次审计汇总和可配置的失败阈值。
5. 构建浏览器演示界面，展示获准、隔离和诊断三个 Arrow 输出。

## 十二 验收标准

1. `moon fmt --check` 通过。
2. `moon check --target all --deny-warn` 无错误和警告。
3. `moon test --target all --deny-warn` 在四个目标上全部通过。
4. 演示能生成 approved、quarantine 和 findings，并显示准确计数。
5. approved 的敏感字段已替换，quarantine 保持原始值。
6. findings 可写入 Arrow IPC 并重新读取。
7. 当前生产代码不包含 DataFrame、查询引擎或 Arrow IPC 的重复实现。
8. README、申报书、差异化说明和代码行为一致。
