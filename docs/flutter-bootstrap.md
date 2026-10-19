# Flutter 云端初始化准备与验收

本任务经用户明确调整为云端初始化：本地暂不安装 Flutter SDK，使用 GitHub Windows Runner 上的官方 `flutter create` 生成工程。这是对当前初始化任务执行位置的授权，不降低 [AGENTS.md](../AGENTS.md)、[协作流程](agent-workflow.md)、[检查清单](agent-review-checklist.md) 与 [CI 方针](ci-build-release.md) 的验收要求。原有四份规范和用户文件保持原样。

## 固定版本与标识建议

- `.fvmrc` 固定 Flutter **3.47.7 stable**，对应 Dart **3.13.5**、框架提交 `abaf9c523780a608bd46686fd5e53740a07077f8`。
- 选择依据：官方 [Windows 发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) 列明该版本于 2026-10-08 发布；[Linux 发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json) 也提供同版本、同框架提交的稳定 SDK，适合后续 Windows 与 Ubuntu Runner。可从 [官方 SDK 归档](https://docs.flutter.dev/install/archive) 核对。
- 工作流从 `.fvmrc` 读取完整版本，通过用户指定的 `subosito/flutter-action@v2` 安装；安装后核对版本、stable 渠道和框架提交，不回退到浮动版本。仅缓存 Runner 的 Flutter SDK，本次不缓存尚无固定锁文件的 pub 依赖。
- 项目名：`polyxia_banner_data_manual_editor`。`--org io.github.sirarikako` 是基于现有 GitHub 命名的开发命名空间建议；实际生成的 Android applicationId 必须在 Artifact Review 中核对，未认定为最终发布标识。
- Windows 产品名建议为 `PolyxiaBannerData.ManualEditor`，程序名建议为 `polyxia_banner_data_manual_editor.exe`。本次官方模板生成不配置 MSIX 或正式发布身份。

## 本次待推送文件与触发

仅新增 `.fvmrc`、`.github/workflows/00-bootstrap.yml` 和本说明。当前阶段仅完成本地准备和静态审查，不推送、不触发 Actions、不生成业务代码，也不创建正式 Release。

批准后，在审查提交范围并创建本地提交后，仅推送 `codex/flutter-bootstrap`。工作流仅响应该分支中 `.fvmrc` 或 `00-bootstrap.yml` 的 push 变化，并再次核对仓库和分支。**推送该提交即会启动云端初始化**，不能把推送与触发视为两个互不相关的动作。

不使用首次 `workflow_dispatch` 作为入口：该事件要求工作流存在于默认分支，详见 [GitHub 事件文档](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch)。本方案无需为初始化修改或合并 `main`。

工作流使用 `windows-latest`、30 分钟 Job 时限和 `contents: read`，其余 Token 权限不授予；checkout 不保留凭据。无需仓库 Secret、AI Key、私有数据访问或 Release 写权限；不运行 AI Agent、不自动提交或推送。首次推送所用的开发者凭据需允许推送分支和新增工作流文件，属于用户批准后的 Git 操作权限，不是 Runner Token 权限。

## 云端执行和 Artifact 范围

1. 在 Runner 临时目录调用固定版本的官方命令：

   ```powershell
   flutter create --no-pub --platforms=android,windows --org io.github.sirarikako --project-name polyxia_banner_data_manual_editor <Runner临时目录>
   ```

2. 不在仓库检出目录运行 create；若仓库已有 `pubspec.yaml`，拒绝重新生成。生成目录和导出目录已存在时也拒绝覆盖；用户文件不会被复制进生成目录。
3. 在生成目录执行 `flutter pub get`、`flutter analyze --no-pub`、`flutter test --no-pub`、`dart format --output=none --set-exit-if-changed .`。任何非零退出码使 Job 失败，不删除测试、不弱化校验；只有检查成功后才导出并上传源文件。
4. 导出遵守官方生成的 Git 忽略规则，限制为基础配置和 `android/`、`windows/`、`lib/`、`test/` 中的源文件，并额外拒绝缓存、构建目录、链接文件或目录、路径越界、凭据配置和签名密钥。保留 `pubspec.lock`、平台源文件、`.gitignore`、`.metadata`、`.fvmrc` 等需要版本管理的文件；不打包 `.git`、SDK、`.dart_tool`、Gradle / IDE 缓存、`local.properties`、临时插件配置或编译中间产物。
5. Artifact 包含 `source/` 和 `bootstrap-manifest.json`；清单记录触发提交、Run、实际 SDK、校验命令以及每个源文件的 SHA256。`source/` 的内容将来对应仓库根目录，不能导入成额外的一层 Flutter 子项目。
6. 上传只针对独立导出目录，设置 `include-hidden-files: true`、文件缺失报错和 7 天保留，不上传整个检出目录或 Runner 临时目录。隐藏文件规则见 [upload-artifact 文档](https://github.com/actions/upload-artifact#uploading-hidden-files)。仓库策略、Action 和 Runner 实际可用性须由真实 Run 确认，本地静态审查不能替代。

## 下载、Review 与后续 DSH 任务

- 用户批准推送后，Codex 检查实际 Run 的 SHA、步骤退出结果和 Artifact；失败时先分析原因，不因缺少本地 SDK 让 DSH 手工重造平台模板。
- 下载后先在隔离目录解包，拒绝绝对路径、`..`、链接和意外文件，核对清单中的所有文件及 SHA256、固定版本和实际平台配置，再决定是否导入。不得直接向仓库根目录覆盖解压。
- 导入前逐项检查目标冲突，保留既有 `AGENTS.md`、`docs/` 及其他用户文件；已有同名文件只在内容一致时跳过，不一致时停止并报告，不使用强制覆盖。现有 `.fvmrc` 应与 Artifact 中的副本一致。
- 初始 Artifact 是官方演示工程及其默认 Widget 测试，**尚不是最终最小应用界面**。Codex Review 后，可按用户已授权的开发范围调用本地 DSH 调整应用名称、最小界面、基础测试，移除不必要的模板依赖和演示功能；不得开发 JSON 业务功能或自行手写 Android / Windows 平台模板。
- DSH 是后续主要开发执行者，Codex 独立审查实际 Diff。保留初次开发和本地 / CI 共享最多 3 轮返工的规则，按调用实际情况记录次数；本阶段未调用 DSH，不消耗返工轮次。

## 验收状态与退出边界

本次本地准备检查包括：分支及基线、固定版本依据、工作流结构与 PowerShell 语法、原文件保护、权限和 Artifact 边界、敏感信息与 Git Diff 范围。仅这些检查可以在本地完成。

- 本地 Flutter analyze / test / format：**未执行，本地无 SDK**。
- 云端初始化及生成模板的 analyze / test / format：**待用户批准推送后执行**，当前不能标记通过。
- 最终工程或 DSH 修改后的提交 CI：**未执行**。首次 Artifact 中的模板检查不能当作最终 PR 提交的 CI；源文件导入、修改并提交后，仍须经批准建立或使用对应提交的 CI，结果必须关联该提交。
- Windows / Android 完整构建及实机验收：**未执行**；本临时工作流不执行这些构建和设备测试。

Artifact 独立 Review、本地 DSH 修改、最终提交 CI 和用户验收全部达到任务要求后，才可声明 Flutter 初始化完整验收通过。完成源文件导入后应在获准范围内移除临时生成工作流，避免把它误用为正式 CI；本说明不提前授权任何远端写入、合并或发布。
