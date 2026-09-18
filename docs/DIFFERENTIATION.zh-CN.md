# 差异化核查

## 核查结论

旧版 MoonQuery 与 MoonFrame 在过滤、排序、分组、连接、表达式和惰性执行上存在明显重合，继续扩展该方向会形成同类 DataFrame 或查询库。当前版本已经删除 `src/query`，改为 Arrow RecordBatch 的质量与隐私发布门禁 MoonSentinel。

差异化来自执行职责，而非名称变化：MoonSentinel 不回答如何查询数据，而是回答哪些行允许离开当前系统、哪些行必须隔离、为什么，以及允许发布的字段是否已经脱敏。

## 对比证据

### MoonFrame

来源：<https://github.com/ihb2032/MoonFrame>

MoonFrame 的公开说明覆盖 DataFrame、CSV/JSON/NDJSON 输入、过滤、排序、空值、分组、连接、表达式、惰性查询和优化。旧版 MoonQuery 的主要算子处在同一功能层，因此已移除。

MoonSentinel 当前没有 Filter、Project、Sort、Group By、Join、查询表达式、逻辑计划或查询优化器。它只按规则生成 approved、quarantine 和 findings。

### shunge arrow

来源：<https://mooncakes.io/docs/shunge/arrow@0.1.0>

`shunge/arrow` 提供 Arrow Schema、Column、RecordBatch、IPC Stream/File 和互操作。MoonSentinel 直接依赖这些公开类型，不实现 FlatBuffers、位图或 IPC 编解码。

项目新增的范围是内容级门禁，包括规则严重度、数据集级和行级 finding、诊断上限、行隔离与放行前脱敏。

### moon-data-contract

来源：<https://mooncakes.io/docs/lyjttio/moon-data-contract@0.2.1>

`moon-data-contract` 的重点是确定性 Schema 治理、演进、兼容性、迁移计划和发布控制。MoonSentinel 不保存 Schema 版本，不计算版本差异，不生成迁移计划。

MoonSentinel 接收一个已经存在的 RecordBatch，检查其中的实际行值，并将同一批次拆分为获准和隔离两部分。两者可以串联使用，但不是同一功能。

### moonbit-jsonschema

来源：<https://mooncakes.io/docs/Xu107-hhh/moonbit-jsonschema>

该项目按 JSON Schema 验证 JSON。MoonSentinel 不解析 JSON、JSON Schema 或引用解析规则，目标数据模型是 Arrow 的类型列。

### MoonJQ

来源：<https://github.com/moonbit-community/moonbit-jq>

MoonJQ 是 JSON 查询解释器。MoonSentinel 没有查询语言，也不产生 JSON 查询结果。

## 当前代码证据

- 生产包只有 `src/gate`。
- `moon.mod` 只声明 `shunge/arrow@0.1.0` 外部依赖。
- 公开 API 由 Contract、Rule、Finding、AuditReport、Redaction 和 ReleaseBundle 构成。
- 演示输出 approved、quarantine 和 findings，不执行通用查询。
- 自动测试覆盖隔离、警告、诊断截断、Schema 错误、IPC 回读、错误合同和输入数组被修改的情况。

## 仍需避免的方向

为保持边界，近期不会添加通用筛选、排序、分组、连接、SQL/JQ 语法或 Schema 版本迁移。如果后续需要选择行，应当只服务于门禁处置，不扩展为通用查询 API。
