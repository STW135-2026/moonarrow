# MoonArrow 开发记录

本记录用于说明每次提交对应的可验证增量。完整细节以 Git 历史、测试和源码为准。

## 2026-09-16：建立首个可运行基线

- `a2575ab`：建立类型、bitmap、array、RecordBatch、compute、DataFrame、
  FlatBuffers、IPC reader、CLI、PyArrow fixture 与多后端测试基线。
- `fc9db2e`：修复干净 CI 环境中的 MoonBit registry 更新步骤，使流水线成功复现。

初版功能已经可运行，但开发内容集中在单个大提交里，无法清晰体现持续开发过程。
后续改为每个功能增量单独提交，并在提交前运行对应测试。

## 2026-09-16：补全 Arrow 类型与查询链路

- `3386a37`：新增 nullable Int64 列及边界测试。
- `09a4430`：新增 Arrow offsets + data 布局的 Binary 列及测试。
- `3df005a`：新增 Int64/Binary filter kernel 和 Int64 条件表达式。
- `948dda2`：让 RecordBatch 完整接入两种新列类型。
- `ee68058`：让 DataFrame 支持 Int64 条件过滤并保留 Binary payload。

## 2026-09-16：补强跨语言证据和用户体验

- `3bf4b51`：IPC Schema/RecordBatch reader 支持 Int64 与 Binary。
- `e404b89`：由 PyArrow 25 重新生成 6 类型夹具，并加入值级互操作断言。
- `3128f8b`：为所有列类型提供安全的诊断值渲染。
- `a0e3975`：IPC inspector 输出前三行预览，评审无需阅读源码即可验证数据。
- `dfffcd2`：CI 在检查与测试后实际运行 DataFrame 和 IPC 两个 MVP 演示。
- `34e1843`：增加一页式 MVP 验收清单。

## 2026-09-16：端到端复核

- 统一 PyArrow 生成器、开发依赖和文档版本，并在生成器中校验版本，确保夹具可复现。
- 补充截断 IPC Stream 与非法 UTF-8 的负向互操作测试，验证外部输入不会被静默接受。
- 修正文档中遗留的类型范围和“双向互操作”表述，明确当前只提供 IPC 读取，写入与
  zero-copy C Data Interface 属于后续工作。

## 持续开发约定

1. 每个提交只承载一个可说明的功能、测试、修复或文档增量。
2. 对外 API 变化同时更新 `pkg.generated.mbti`、测试和变更记录。
3. 每次推送由 GitHub Actions 复现格式检查、接口生成、全目标检查、全目标测试与
   CLI 冒烟演示。
4. 不通过拆分空提交或机械改名增加提交数；提交历史必须对应真实工程进展。
