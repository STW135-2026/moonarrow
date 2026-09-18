# MoonQuery 开发记录

## 2026-09-18：重新划定项目边界

审核指出原 MoonArrow 与已维护的 `shunge/arrow` 高度重叠。复核后确认，对方模块已经
提供 Arrow Schema/Column/RecordBatch、IPC Stream/File 读写、格式校验和多后端
测试，因此继续扩展同类 IPC 功能没有足够独立价值。

本次改造不是更换文案，而是进行了代码级转型：

1. 项目更名为 MoonQuery。
2. `moon.mod` 增加并锁定 `shunge/arrow@0.1.0`。
3. 删除当前树中的自研 IPC、FlatBuffers、bitmap、array、RecordBatch 和相关夹具。
4. 新增独立查询包 `src/query`。
5. 实现谓词、三值逻辑、查询计划、Explain、Filter、Project、Limit、Sort、Group By、
   SUM、COUNT 和 Inner Join。
6. 新演示使用公开依赖完成 Arrow IPC 输出和回读。
7. 重写 README、申报书、架构、差异化说明、演示和验收文档。

旧实现仍保留在 Git 历史中供审计，但不属于 MoonQuery 当前代码或申报成果。

## 验证原则

- 只有四后端测试通过的能力才进入“已实现”列表。
- 底层依赖提供的能力必须明确署名，不能作为 MoonQuery 原创成果。
- 性能优化未完成前，明确写出稳定插入排序和嵌套循环 Join，不使用“高性能”宣传。
- 每次提交运行格式检查、接口生成、全目标检查、全目标测试和 CLI 演示。
