# MoonQuery MVP 验收清单

## 1. 依赖和范围

- [x] `moon.mod` 锁定 `shunge/arrow@0.1.0`。
- [x] 生产代码只有 `src/query`。
- [x] 不包含自研 IPC、FlatBuffers、bitmap、Arrow array 或 RecordBatch。
- [x] README 和申报书明确区分交换层与查询层。

## 2. 构建和测试

```sh
moon update
moon fmt --check
moon info
moon check --target all --deny-warn
moon test --target all --deny-warn
```

验收要求：Native、JS、Wasm、Wasm-GC 全部通过，且没有 MoonBit 警告。

## 3. 查询语义

- [x] 类型化 Boolean、Int32、Int64、UTF-8 谓词。
- [x] AND、OR、NOT 三值逻辑。
- [x] Filter、Project、Limit。
- [x] 稳定排序且 null 始终置后。
- [x] UTF-8 Group By、nullable Int32 SUM、COUNT。
- [x] Boolean、Int32、Int64、UTF-8 key 内连接。
- [x] null join key 不匹配。
- [x] 重名 join 字段通过前缀消歧。
- [x] 缺列、错类型、空投影和非法 limit 返回结构化错误。

## 4. 可运行演示

```sh
moon run cmd/main --target native
```

验收要求：

1. 打印包含 Scan、Filter、GroupBy、Sort 和 Limit 的逻辑计划。
2. 输出 East 组的 `revenue_sum=320`、`orders=2`。
3. 显示由 `shunge/arrow` 完成的 IPC handoff 和回读行数。

## 5. 防止误报

- [x] 未宣称当前实现是向量化执行。
- [x] 未宣称当前 Sort/Join 已针对大数据优化。
- [x] 未把依赖提供的 IPC 和 Arrow 类型列为原创成果。
- [x] 所有“已实现”条目均有代码和测试对应。
