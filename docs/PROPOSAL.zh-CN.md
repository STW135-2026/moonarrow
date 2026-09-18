# MoonQuery 项目申报书

## 一、项目基本信息

- 项目名称：MoonQuery
- 项目副标题：面向 MoonBit 与 WebAssembly 的嵌入式列式查询引擎
- 项目负责人：苏天伟
- 开源许可证：Apache-2.0
- 代码仓库：<https://github.com/STW135-2026/moonquery>
- 底层开源依赖：`shunge/arrow@0.1.0`（MIT）

## 二、项目简介

MoonQuery 是运行在 Arrow RecordBatch 之上的 MoonBit 查询执行层。它接收由
`shunge/arrow` 读取或创建的列式数据，通过可组合谓词和逻辑查询计划完成过滤、
投影、限制、排序、分组聚合及内连接，再把合法的 Arrow RecordBatch 交还给
`shunge/arrow` 输出为标准 Arrow IPC 数据。

MoonQuery 不实现 IPC Stream/File 编解码、FlatBuffers、Arrow 位图或另一套
Schema/RecordBatch。这些格式基础设施直接复用现有 `shunge/arrow`，项目代码仅
聚焦其未覆盖的查询与计算层。

## 三、项目背景和实际价值

Arrow 解决的是不同语言与系统之间如何交换列式数据，但“能够读取数据”并不等于
“能够在 MoonBit 中查询数据”。MoonBit 应用在收到数据库、Python 数据工具或
浏览器端的 Arrow 批次后，仍然需要过滤、选列、排序、分组统计和表关联。

MoonQuery 补齐这一层能力，主要面向以下场景：

1. 浏览器离线分析：MoonBit/Wasm 在本地处理 Arrow 数据，无需把敏感数据上传服务端。
2. 数据库结果后处理：对 Arrow 格式的查询结果继续筛选、聚合或关联小型维表。
3. ETL 和数据验证：把读取、变换、重新输出连接成可测试的 MoonBit 数据流水线。
4. MoonBit 数据应用原型：为报表、可视化前处理和嵌入式分析提供统一执行核心。

## 四、当前已完成且可验证的成果

仓库当前版本已经实现并通过自动测试：

- 类型化谓词：Boolean、Int32、Int64、UTF-8 比较。
- `AND`、`OR`、`NOT` 的 SQL 风格三值逻辑；Filter 只保留结果为 true 的行。
- 延迟构建、按顺序执行并可输出 Explain 文本的逻辑查询计划。
- Filter、Project、Limit 和稳定排序，排序时 null 始终置后。
- UTF-8 key 分组、nullable Int32 的 SUM、每组 COUNT。
- Boolean、Int32、Int64、UTF-8 key 的内连接；null key 不匹配。
- Join 输出统一增加 `left.`、`right.` 前缀，避免重名字段产生歧义。
- 查询错误结构化返回，包括缺失列、重复列、类型错误、非法 limit 和不支持操作。
- 每个查询算子的结果均通过 `shunge/arrow.RecordBatch::new` 重新校验。
- 查询结果通过 `shunge/arrow` 写入 Arrow IPC Stream 后再次读取验证。
- Native、JavaScript、Wasm、Wasm-GC 四个目标的测试。

## 五、核心设计

MoonQuery 把查询分成三个部分：

1. **数据层**：直接使用 `shunge/arrow` 的 Schema、Column 和 RecordBatch。
2. **计划层**：Query 保存数据源和有序 QueryStep；构建时不执行，调用 `execute`
   时按顺序运行；`explain` 输出相同的计划。
3. **执行层**：各算子生成新的 Arrow 列和 RecordBatch，并在边界重新验证类型、长度
   和 nullability。

谓词求值使用三值逻辑。例如 `null AND false` 为 false，`null OR true` 为 true，
其余无法确定的结果仍为 null；Filter 阶段仅选中 true，与 SQL WHERE 行为一致。

## 六、与现有 `shunge/arrow` 的互补边界

`shunge/arrow` 的职责是 Arrow IPC 交换，包括数据结构、Stream/File 读写、格式检查
和跨语言互操作。MoonQuery 的职责是消费这些 RecordBatch 并执行查询。

| 范围 | `shunge/arrow` | MoonQuery |
| --- | --- | --- |
| Arrow 数据结构 | 实现并维护 | 直接依赖 |
| IPC 读写 | 实现并维护 | 不实现 |
| FlatBuffers/位图 | 实现并维护 | 不实现 |
| Filter/Project/Limit | 不负责 | 已实现 |
| 三值逻辑谓词 | 不负责 | 已实现 |
| Sort | 不负责 | 已实现 |
| Group By/SUM/COUNT | 不负责 | 已实现 |
| Join | 不负责 | 已实现 |
| Query Plan/Explain | 不负责 | 已实现 |

代码级证据包括：`moon.mod` 明确依赖 `shunge/arrow@0.1.0`；生产代码只有
`src/query`；仓库不存在自研 IPC、FlatBuffers、位图、Arrow Schema 或
RecordBatch 实现。两者是“交换层 → 查询层”的依赖关系，而不是两个同类库。

## 七、可运行演示

演示构造包含区域、商品、销量、收入和状态的 Arrow RecordBatch，然后执行：

1. 筛选 `units > 2 AND active IS TRUE`；
2. 按 region 分组；
3. 计算 revenue 的 SUM 和每组 COUNT；
4. 按 revenue_sum 降序排列；
5. 取前三行；
6. 由 `shunge/arrow` 写成 Arrow IPC 并重新读回。

运行命令：

```sh
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run cmd/main --target native
```

## 八、创新点

1. 在 MoonBit 生态中把 Arrow “数据交换能力”推进到“可组合查询能力”。
2. 查询计划可解释、可复现，便于在浏览器/Wasm 和原生程序中使用同一套语义。
3. 从第一版就处理 null、类型错误、字段冲突和结果批次校验，而不是只演示正常输入。
4. 通过明确依赖现有模块形成生态协作，避免重复实现和分裂基础数据格式。

## 九、原创边界

MoonQuery 的查询计划、谓词语义、算子实现、错误模型、测试和演示均位于本仓库。
Arrow 格式、Schema、Column、RecordBatch 及 IPC 编解码来自公开依赖
`shunge/arrow`，不作为本项目原创成果申报。仓库保留 Git 历史，能够核查项目从
早期探索到重新划定边界的过程。

## 十、当前限制与后续路线

当前 MVP 为保证行为可验证，稳定排序使用插入排序，Join 使用嵌套循环；尚未声称
针对大数据量优化。分组聚合目前限定 UTF-8 key 与 Int32 SUM/COUNT。项目尚未实现
SQL 文本解析、成本优化、并行执行、磁盘溢写、窗口函数或流式增量查询。

下一阶段将优先增加通用标量表达式、更多聚合、哈希聚合与哈希 Join，并使用可复现
基准验证性能；只有完成和测试通过的能力才会写入已实现清单。

## 十一、验收标准

1. `moon check --target all --deny-warn` 无编译错误和警告。
2. `moon test --target all --deny-warn` 四后端全部通过。
3. CLI 能打印逻辑计划和正确聚合结果。
4. CLI 能把结果写成 Arrow IPC 并用同一公开依赖重新读取。
5. 仓库生产代码不存在与 `shunge/arrow` 重复的 IPC/FlatBuffers/位图实现。
6. README、申报书、差异化说明和实际代码保持一致。
