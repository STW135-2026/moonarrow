# Changelog

## 0.2.0

- 将项目从 MoonQuery 更名并重构为 MoonSentinel。
- 移除与 MoonFrame 重合的查询、排序、分组、连接和逻辑计划实现。
- 新增 Arrow RecordBatch 质量规则、错误和警告严重度、行隔离与数据集级阻断。
- 新增受限诊断收集、准确总计和 Arrow 原生 findings 输出。
- 新增 approved 字段替换脱敏和 quarantine 原值保留。
- 新增 7 项测试，并在 Native、JavaScript、Wasm、Wasm-GC 上验证。

## 0.1.0

- 初始 MoonQuery 探索版本。该版本只保留在 Git 历史中，不属于当前申报成果。
