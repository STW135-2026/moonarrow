# MoonArrow 三分钟演示脚本

## 一句话介绍

MoonArrow 是 MoonBit 原生的 Apache Arrow IPC 与列式计算内核：它让 MoonBit
程序直接接入 Python 和数据系统已经广泛使用的 Arrow 数据交换格式，并能在
Native、JavaScript 与 WebAssembly 上复用同一套计算代码。

## 演示流程

### 1. 证明输入来自外部生态

展示 `tools/generate_fixtures.py`：Schema 和 RecordBatch 由 PyArrow 25.0.1 创建，产物
是提交在 `fixtures/pyarrow-basic.arrows` 的二进制 IPC 流，不是 MoonArrow 自己生成
后再自己读取。

### 2. MoonBit 直接读取 Arrow

运行：

```bash
moon run cmd/ipc_inspect --target native
```

预期输出：

```text
MoonArrow IPC inspector
file: fixtures/pyarrow-basic.arrows
fields: 6
  city: utf8 (required)
  temperature_c: int32 (nullable)
  active: bool (nullable)
  score: float64 (nullable)
  sequence: int64 (nullable)
  payload: binary (nullable)
record batches: 1
  batch 0: 4 rows
    row 0
      city: Shenzhen
      temperature_c: 31
      active: true
      score: 9.5
      sequence: 4294967296
      payload: <binary: 2 bytes>
```

这里重点说明：MoonArrow 解码的是 Arrow 的 FlatBuffers 元数据和列式 body buffers，
不是把文件转换成 JSON 后再读取。

### 3. 展示实际查询 API

运行：

```bash
moon run cmd/main
```

代码通过 DataFrame 链式调用筛选 `temperature_c > 25`，再投影城市与温度列，并计算
包含空值列的 sum 和 mean。

### 4. 展示工程可信度

运行：

```bash
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
```

测试覆盖四种后端；Native 额外执行从文件系统读取 PyArrow 二进制夹具的互操作测试。

## 评审要点

- **生态价值**：不是孤立的新格式，而是接入 Arrow/PyArrow/Polars/数据库生态的桥梁。
- **MoonBit 特性**：代数数据类型表达 Schema、Column 与结构化错误；同一代码库输出
  Native、JS、Wasm 和 WasmGC。
- **技术深度**：实现 IPC framing、FlatBuffers table/vtable、对齐、端序、bitmap、
  offsets 和 RecordBatch 约束，不依赖现成 Arrow 运行库。
- **安全边界**：外部二进制输入经过逐层 bounds check，格式损坏与尚未支持的合法
  Arrow 特性被明确区分。
- **可扩展性**：array、compute、record batch、IPC、DataFrame 分层，后续可独立增加
  类型、writer、CSV/Parquet 与浏览器可视化。

## 下一次最有价值的迭代

1. 实现 IPC writer，并由 PyArrow 反向读取 MoonArrow 产物，形成双向互操作证据。
2. 增加更多整数宽度、List、Struct 和 Dictionary 类型。
3. 增加 sort、group-by/hash aggregate 与表达式 AST。
4. 做浏览器 Wasm demo：本地加载 Arrow 文件、筛选并绘图，全程不上传数据。
