# MoonQuery 差异化与互补边界

## 结论

MoonQuery 不是 Arrow IPC 库。项目以 `shunge/arrow@0.1.0` 为唯一 Arrow 数据与
IPC 基础层，只实现查询表达式、逻辑计划和数据算子。

## 可核查的代码证据

1. `moon.mod` 直接声明 `shunge/arrow@0.1.0`。
2. 唯一生产库包是 `src/query`，其 `moon.pkg` 直接导入 `shunge/arrow`。
3. 查询输入和输出类型均为 `@arrow.RecordBatch`，没有自定义替代类型。
4. IPC 演示调用 `@arrow.write_stream` 和 `@arrow.read_stream`，不包含自研编解码器。
5. 当前树中不存在 `ipc`、`flatbuffer`、`bitmap` 或自定义 Arrow array 包。

## 功能边界

| 用户需求 | 由谁完成 | 代码位置 |
| --- | --- | --- |
| 构造 Arrow Schema/RecordBatch | `shunge/arrow` | 外部依赖 |
| 读取/写入 Arrow IPC | `shunge/arrow` | 外部依赖 |
| 校验 Arrow 批次布局 | `shunge/arrow` | 外部依赖 |
| 组合过滤条件 | MoonQuery | `Predicate` |
| SQL 风格 null 逻辑 | MoonQuery | `and_3vl`、`or_3vl` |
| 构建/解释查询计划 | MoonQuery | `Query`、`QueryStep` |
| Filter/Project/Limit/Sort | MoonQuery | `src/query/query.mbt` |
| Group By/SUM/COUNT | MoonQuery | `group_utf8_sum_int32` |
| Inner Join | MoonQuery | `inner_join_batch` |

## 为什么不是重复实现

`shunge/arrow` 解决“数据如何以 Arrow 格式进入和离开 MoonBit”；MoonQuery 解决
“进入 MoonBit 后如何查询和变换”。如果没有 `shunge/arrow`，MoonQuery 不负责读取
Arrow 字节；如果没有 MoonQuery，`shunge/arrow` 仍然可以正常完成 IPC 交换，但不会
提供这里的查询计划和算子。二者可以分别维护，也可以串联使用。

## 主动排除的范围

为避免重新形成重叠，MoonQuery 明确不把以下内容列入自身路线：

- Arrow IPC Stream/File 编解码。
- FlatBuffers 元数据读写。
- Arrow validity bitmap 与物理 buffer 布局。
- 基础 Arrow Schema/Column/RecordBatch 类型。
- PyArrow 格式兼容性测试矩阵。

若底层格式需要扩展，应向 `shunge/arrow` 提交需求或贡献；MoonQuery 只在其公开类型
之上扩展查询能力。
