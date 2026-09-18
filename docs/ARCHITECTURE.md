# MoonSentinel 技术架构

## 处理边界

MoonSentinel 位于 Arrow 数据交换层与下游消费方之间。`shunge/arrow` 负责 Schema、Column、RecordBatch 和 IPC；MoonSentinel 负责判断一个批次中的哪些行可以发布，并生成可供系统处理的诊断。

```text
Arrow RecordBatch + Contract + Redactions
                    |
                    v
         batch and contract validation
                    |
                    v
          deterministic rule audit
                    |
          +---------+----------+
          |                    |
          v                    v
   accepted indices      rejected indices
          |                    |
          v                    v
   approved + masking      quarantine
          \                    /
           +------ findings --+
```

## 核心对象

`Contract` 保存合同名称、规则副本和诊断上限。构造时检查空名称、空规则集、重复规则编号、非法范围和重复允许值。

`Rule` 描述必需列、非空、数值范围、字符串约束、唯一性和跨字段顺序。每条规则都包含稳定编号和严重度。

`AuditReport` 保存总错误数、总警告数、受限的 Finding 数组以及 accepted 和 rejected 行索引。截断只影响明细保存，不影响统计或隔离决策。

`ReleaseBundle` 返回 approved、quarantine、findings 和 AuditReport。三个数据结果均为 `shunge/arrow.RecordBatch`。

## 错误语义

- `Error` 行级 finding 标记对应行；数据集级 finding 标记所有行。
- `Warning` 只增加警告计数，不改变行去向。
- 输入 RecordBatch 在审计前重新执行 `validate`，可发现构造后被调用方修改的底层数组。
- 规则引用缺失列或错误类型时产生数据集级 finding，不发生隐式类型转换。
- 无法构造合法输出、合同无效或脱敏配置无效时返回 `GateError`。

## 确定性

规则按照合同中的数组顺序执行，行按照源行号递增检查。输出行保持源顺序，finding 顺序由规则顺序和行顺序共同确定。该约束使测试、日志和审核结果可以复现。

## 内存限制

`max_findings` 限制保存的 Finding 数量。执行仍然扫描所有规则和行，因此 `error_count`、`warning_count` 和行隔离结果保持准确。当前批次输出需要为 approved 和 quarantine 创建新列数组；项目没有声称零拷贝。

## 安全考虑

- Finding 的 message 只描述规则和字段，不写入原始字段值，降低诊断泄露风险。
- 脱敏只处理 approved。quarantine 保留原值，调用方应将其放入受限存储。
- 重复脱敏列、缺失列和非 UTF-8 列均会拒绝发布调用。
- MoonSentinel 不负责加密、身份认证、密钥托管或 quarantine 的访问控制。
