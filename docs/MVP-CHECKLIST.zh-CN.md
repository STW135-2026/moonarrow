# MoonArrow MVP 验收清单

本页用于让评审者在几分钟内确认 MoonArrow 不是设计稿，而是可构建、可运行、
可测试、可复现的 MoonBit 基础软件 MVP。

## 一条命令完成质量检查

```bash
moon update
moon fmt --check
moon info
moon check --target all --deny-warn
moon test --target all --deny-warn
```

当前测试基线：Wasm、WasmGC、JavaScript 各 41 项，Native 44 项；Native
额外执行真实文件系统上的 PyArrow 互操作测试。

## 可运行演示

### 1. DataFrame 查询

```bash
moon run cmd/main
```

该演示构造包含空值的城市温度表，执行 `temperature_c > 25` 过滤、列投影、
`sum` 与 `mean` 聚合，并输出筛选结果行数。

### 2. Arrow IPC 检查器

```bash
moon run cmd/ipc_inspect --target native
```

检查器读取 `fixtures/pyarrow-basic.arrows`，输出 Schema、RecordBatch 数量与前三行
数据预览。该二进制文件由固定版本 PyArrow 25.0.1 生成，不是 MoonArrow 自己写入后
再自行读取。

## 已完成的 MVP 范围

| 能力 | 可验证证据 |
| --- | --- |
| Arrow Schema 与 Field | `src/types` 的校验与单元测试 |
| 列式内存数组 | `Boolean`、`Int32`、`Int64`、`Float64`、`Utf8`、`Binary` |
| 空值语义 | Arrow LSB-first validity bitmap 与跨类型空值测试 |
| RecordBatch | 列数、类型、长度、非空约束校验 |
| 计算内核 | filter、take、比较、sum、mean、min/max |
| DataFrame | select、filter、limit、Int32/Int64 条件查询与聚合 |
| Arrow IPC Stream | framing、FlatBuffers metadata、Schema 与 RecordBatch 解码 |
| 跨语言互操作 | PyArrow 25.0.1 生成 6 种类型的固定测试夹具 |
| 多后端 | Native、JavaScript、WebAssembly、WasmGC |
| 自动化质量门禁 | GitHub Actions 执行格式、接口、检查、测试与 CLI 冒烟演示 |

## 错误与安全边界

MoonArrow 不信任外部 IPC 数据。读取路径会检查消息长度、FlatBuffers table/vtable、
buffer 范围、offset 单调性、validity 长度、UTF-8 合法性、节点行数与空值数量。
尚未支持但格式合法的特性会返回结构化 `Unsupported*` 错误，而不是被误判为损坏。

## 明确未包含的范围

当前 MVP 聚焦平面列、IPC Stream 读取与单机列式查询。Dictionary、List/Struct、
压缩、IPC File 容器、IPC 写入、Parquet 与分布式执行属于后续里程碑，不在本次
MVP 完成条件内。

## 独立复现夹具

```bash
python -m pip install -r requirements-dev.txt
python tools/generate_fixtures.py
moon test tests/interop --target native --deny-warn
```

重新生成后测试仍须通过，以证明二进制兼容性来自公开 Arrow 规范和 PyArrow 行为，
而不是依赖手工构造的特例。
