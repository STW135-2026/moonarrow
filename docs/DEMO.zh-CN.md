# MoonSentinel 演示步骤

## 准备

```sh
moon update
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
```

预期结果是 7 项测试在 wasm、wasm-gc、js、native 四个目标上全部通过。

## 运行

```sh
moon run cmd/main --target native --deny-warn
```

演示批次有 4 行。规则包括客户编号唯一、年龄必填且在 0 到 120 之间、国家在 CN/US 允许列表内、最小订单不大于最大订单，以及邮件缺失警告。放行数据的 email 会替换为 `[REDACTED]`。

预期输出：

```text
MoonSentinel release gate
customer-export-v1: FAIL; rows=4; accepted=1; quarantined=3; errors=7; warnings=1; findings_shown=8; truncated=false
approved rows: 1
quarantined rows: 3
diagnostic rows: 8
approved email: [REDACTED]
Arrow IPC handoff: 1432 bytes, 1 approved row
```

IPC 字节数可能随底层依赖版本变化；行数、问题计数和脱敏结果是验收依据。

## 讲解顺序

1. 打开 `src/gate/gate.mbt`，说明 Rule、Severity 和 Finding。
2. 展示 `Contract::audit` 如何得到 accepted 和 rejected 行索引。
3. 展示 `Contract::release` 如何生成三个 RecordBatch，并只对 approved 脱敏。
4. 运行测试，说明四后端使用相同规则语义。
5. 打开差异化核查，解释本项目不再实现查询引擎。
