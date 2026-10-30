# Flutter CI、Windows 优先测试与发布边界

当前项目使用 [`01-ci.yml`](../.github/workflows/01-ci.yml) 执行 PR / main 的 format、analyze、test，使用 [`02-build.yml`](../.github/workflows/02-build.yml) 手动或复用方式构建 Windows / Android。文档描述现役工作流，不代表未实现功能已存在。协作规则见 [AGENTS.md](../AGENTS.md)。

## 环境分工
| 环境 | 责任 |
| --- | --- |
| ChatGPT + GitHub 功能分支 | 实现、代码审查、提交 PR、处理测试反馈 |
| 用户 Windows 11 / Codex | 按固定 Flutter 版本独立测试、Windows 运行验收；不调用 DSH |
| GitHub Ubuntu Runner | Flutter 快速 CI、可选 Android APK 构建 |
| GitHub Windows Runner | 按需 Windows Release ZIP 构建 |
| Android 真机 | 环境后续配置；当前 P0/P1 不要求实机验收 |

## 验证要求
1. `.fvmrc` 和 `pubspec.lock` 必须保持一致；CI 使用 locked dependencies、格式、analyze、test。
2. 测试只用公开数据或合成样例，不访问私有仓库，不记录 Token，不把正式人工数据覆盖写入。
3. PR head SHA 与 CI 实际检出的 merge SHA 可能不同；验收必须对应当前代码，不引用旧提交结果。
4. Windows 云端成功只证明可构建，不证明启动与编辑行为。Codex 应独立运行 Windows 应用。
5. Android 云端 APK 成功不等于 Android 真机成功。当前未配置 Android 测试环境，明确报告未执行；不能阻断约定的 Windows 优先交付。
6. Android 与 Windows 按需分别构建；`02-build.yml` 的 Artifacts 保留 7 天。禁止使用历史 Artifact 代替当前 SHA。
7. Release 仅在用户批准、相关验收达标后另行执行；不得自动提交 main、发 Tag、修改历史 Release 或正式数据。
8. 未来若增加 `03-release.yml`，应验证 Tag 归属 main 可信提交、该提交 CI 成功、双平台构建和 SHA256，遵守最小权限与用户明确授权。

本文件不规定自动运行 AI Agent 的工作流，也不引入 DSH 或任何模型 API 凭据。
