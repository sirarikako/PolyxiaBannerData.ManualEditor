# Polyxia Manual Editor — 协作规则

本仓库是**完全公开**的 Flutter Windows / Android 应用仓库，与 PolyxiaBannerData 数据生产仓库分离。当前开发采用 **ChatGPT 实现 → GitHub 功能分支 / PR → Codex 独立测试 → 用户验收**，不再调用 DSH。历史 DSH 协作记录可保留作参考，但不构成当前任务约束。

## 角色与权限

- **ChatGPT**：分析需求、设计与实现业务代码和自动化测试，静态审查实际修改，创建独立分支和 PR，按照测试反馈修复。
- **Codex（用户的 Windows 环境）**：独立核查 Git 差异、执行 Flutter 格式检查、静态分析、单元 / Widget 测试和 Windows 运行验收；可提出故障与复现报告，但**不负责修改业务代码**，除非用户另行授权。
- **用户**：选择范围、运行或委托 Windows / Android 实机验收、决定是否合并及正式发布。
- GitHub Actions：使用现有 CI 和按需构建，不运行 AI Agent。
- 当前 Android SDK / 真机验收条件尚未就绪；**首轮 Windows 优先**。云端 Android 构建可独立验证，但不能把 APK 构建成功冒充 Android 实机通过。

## Git 与安全

1. 每项开发使用独立 feature 分支；未经明确授权不得直接修改 `main`、合并 PR、发布 Tag / Release 或覆盖正式产物。
2. 开发前记录 main HEAD 与工作范围；提交后核对实际差异与分支。不得删除或回退用户原有修改，不强制推送、不执行破坏性 Git 清理。
3. 不往公开代码、测试、工作流、日志或示例数据提交 Token、密钥、用户私人数据。
4. 不直接写入 PolyxiaBannerData 正式 V1 数据；ManualEditor 只读取公开 v1 并生成符合 `schemas/manual/` 的人工输入 JSON，由数据仓库原有流程核验、导入及发布。
5. 不生成虚构官方帖子 ID、物品 ID、官方来源或翻译。来源不存在时按独立 missing 格式处理（后续阶段），不能伪造来源。
6. 新增依赖应说明必要性并保持 `pubspec.lock` 一致；`.fvmrc` 锁定 Flutter 版本，不擅自升级。

## 开发质量与验收

- 修改 Dart 后应测试边界、无效数据、重复操作、异步失败与状态切换，且保留有效测试，不用削弱校验换取通过。
- PR CI 必须对应当前 commit / merge 测试 SHA。构建、静态检查、Windows 实机、Android 实机分别报告。
- Windows 测试至少包括启动、公开数据加载、切换游戏 / 版本、编辑 upcoming 与 existing、生成 JSON、失败和非法输入。
- Android 暂不作为 P0 / P1 完工阻塞；应注明未执行，保留 Flutter 跨平台代码，后续有环境再补充验收。
- 所有外部数据（包括 GitHub JSON）均按不可信输入处理；写盘前显示目标路径并避免覆盖其他文件。
- PR 不自动合并。测试反馈交回 ChatGPT 修复，重新检查新提交的 CI。
- 本仓库约定、测试步骤、Windows / Android 边界分别见 [开发流程](docs/agent-workflow.md)、[审查清单](docs/agent-review-checklist.md)、[CI / 构建](docs/ci-build-release.md)。

## 每次交付报告

列出目标、分支 / PR / SHA、修改文件、实际执行的测试与日志或链接、Windows 与 Android 各自的验证状态、问题及待用户验收项。未运行的检查必须明确标注，不依据其他人的总结宣称通过。
