# MoonArrow 项目申报书

## 当前可运行成果

首个可验证版本已经完成，不只是设计稿：

- 可读取 PyArrow 25 生成的真实 Arrow IPC Stream。
- 支持平面 `Boolean`、`Int32`、`Int64`、`Float64`、`Utf8`、`Binary`
  Schema 与 RecordBatch。
- 正确处理 validity bitmap、bit-packed Boolean、字符串 offsets 和空值。
- 提供 DataFrame 投影、过滤、limit、sum、mean API。
- 提供带数据预览的 IPC 检查器、PyArrow 独立夹具和
  Native/JS/Wasm/WasmGC 测试。
- 对越界 FlatBuffers、截断消息、非法 buffer、offset、validity 和 UTF-8
  返回结构化错误。

## 项目定位

MoonArrow 是使用 MoonBit 实现的 Apache Arrow 兼容列式内存、IPC 与计算基础库。
项目希望让 MoonBit 程序能够高效处理结构化数据，并与 Python、Rust、JavaScript
和数据库生态交换 Arrow 数据。

## 使用场景

1. MoonBit 数据程序读取 PyArrow、Polars 或数据库生成的 Arrow IPC 数据，并进行
   无需逐行反序列化的列式计算。
2. 浏览器应用通过 MoonBit/Wasm 加载 Arrow 数据，在本地完成筛选、聚合和可视化
   前处理，避免上传敏感数据。
3. 数据库、AI 推理及 ETL 工具以 MoonArrow 的 RecordBatch 作为统一交换层，减少
   各组件之间的格式转换和重复内存分配。

## 核心功能

- Arrow 风格 Schema、Field、Array、Bitmap 和 RecordBatch。
- 已完成 Nullable Boolean、Int32、Int64、Float64、UTF-8 与 Binary；后续
  扩展更多整数宽度与嵌套数组。
- 已完成 Arrow IPC Stream 读取与跨语言兼容测试；IPC 写入和 File 容器属于
  下一里程碑。
- 已完成过滤、投影和基础聚合；排序与 Join 属于后续计算里程碑。
- 已完成 JS、Wasm、WasmGC、Native 多后端与 Native CLI 演示；浏览器界面属于
  后续生态集成工作。

## 技术路径

项目采用自底向上的分层结构：首先实现并验证 bitmap、buffer 和 array 的物理布局，
再构建 schema、record batch 与 compute kernels，随后依据 Apache Arrow IPC 规范实现
FlatBuffers 元数据和消息帧，最终使用 PyArrow 生成的固定夹具进行双向兼容测试。

MoonBit 的代数数据类型和模式匹配用于表达 Arrow 类型与计算表达式；统一工具链和
多后端能力使同一套列式核心能够运行于 Native、JavaScript 和 WebAssembly。

## 工程边界

项目首先交付 Arrow 内存格式、IPC 和单机计算内核，不在早期阶段实现完整 SQL、
分布式执行、对象存储或与 Pandas 完全一致的 API。Parquet 和分布式查询作为后续
独立里程碑。

## 参考与合规

实现依据 Apache Arrow 公开格式规范，并参考 Apache Arrow Rust、C++、JavaScript
与 PyArrow 的公开行为及测试数据。所有参考来源和兼容测试生成方式将在仓库中记录；
项目采用 Apache-2.0 许可证。

## MVP 验收方式

仓库提供 `docs/MVP-CHECKLIST.zh-CN.md`，列出一条命令质量检查、两个可运行演示、
PyArrow 夹具再生成方式、当前边界与逐项证据。GitHub Actions 会在每次推送后执行
格式检查、接口生成、四后端检查与测试，并实际运行 DataFrame 和 IPC CLI 演示。

开发过程通过独立功能提交与 `docs/DEVELOPMENT_LOG.zh-CN.md` 持续记录，避免把所有
工作压缩成单次不可追踪提交。
