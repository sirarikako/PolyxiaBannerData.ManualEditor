# Flutter 云端初始化与工程导入记录

本项目经用户授权在 GitHub Windows Runner 使用官方 `flutter create` 生成 Android / Windows 工程，再由 Codex 校验 Artifact 并导入仓库根目录。本地 Windows VM 暂未安装 Flutter SDK。本记录补充当前任务证据；协作分工、验收和返工规则仍以 [AGENTS.md](../AGENTS.md)、[协作流程](agent-workflow.md)、[检查清单](agent-review-checklist.md) 和 [CI 方针](ci-build-release.md) 为准，原有四份规范未修改。

## 1. 固定版本与生成来源

- `.fvmrc` 固定 Flutter **3.47.7 stable**，对应 Dart **3.13.5**，框架提交 `abaf9c523780a608bd46686fd5e53740a07077f8`。
- 原选择依据：官方 [Windows 发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json) 列明该版本于 2026-10-08 发布；[Linux 发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json) 提供同版本、同框架提交的稳定 SDK，适用于后续 Windows 和 Ubuntu Runner。版本可从 [官方 SDK 归档](https://docs.flutter.dev/install/archive) 核对；实际安装版本也已由初始化 Run 验证。
- 来源仓库：`sirarikako/PolyxiaBannerData.ManualEditor`；分支：`codex/flutter-bootstrap`。
- 生成工作流提交：`93c35064eb7238659a0d5a8f366af4039d8a698a`。
- [初始化 Run #1](https://github.com/sirarikako/PolyxiaBannerData.ManualEditor/actions/runs/39240066092)：Run ID `39240066092`，attempt `1`，状态 `success`，Windows Runner 所有步骤成功。

Runner 在独立临时目录执行以下官方命令，未覆盖仓库检出目录：

```powershell
flutter create --no-pub --platforms=android,windows --org io.github.sirarikako --project-name polyxia_banner_data_manual_editor <Runner临时目录>
```

随后执行依赖恢复、analyze、test 和格式检查，仅在检查成功后导出符合版本管理要求的源文件。临时工作流 `00-bootstrap.yml` 已在本次导入中删除；既有提交、Run 及 Actions 日志未删除，不再保留可重复生成模板的入口。

## 2. Artifact 与完整性校验

| 项目 | 独立核查结果 |
| --- | --- |
| Artifact | `flutter-bootstrap-93c35064eb7238659a0d5a8f366af4039d8a698a-39240066092-1` |
| Artifact ID | `12181425798` |
| 下载 ZIP 大小 | 53,461 字节 |
| ZIP SHA256 | `f635d61e1071a870dc2abcaf24c51f9e1adb6a92cbb67eedef89c3a054bb3cee` |
| 保留期限 | 7 天；到期时间 `2026-10-26T10:51:17Z`；本次下载时未过期 |
| 包内内容 | `bootstrap-manifest.json` 与 `source/` 下 46 个源文件 |
| 清单校验 | 仓库、源提交、Run / attempt、Flutter / Dart 版本与指定来源一致 |
| 源文件 SHA256 | 全部 46 个逐项重新计算，与清单一致 |

下载与解包在仓库外的独立临时目录进行；导入前拒绝绝对路径、路径越界、大小写重复、符号链接和意外文件。检查包含隐藏配置文件，未发现 SDK、缓存、凭据、签名密钥、私有数据或编译中间产物。ZIP 摘要用于核对下载包，每个源文件另行核对，不能互相替代。

实际新增导入 **45 个文件**，复制后的工作区内容与清单逐字节一致；已有 `.fvmrc` 与 Artifact 内容一致（仅换行形式不同），保留本地原始字节，未盲目覆盖。仓库现有 `core.autocrlf=true` 在暂存时将其中 34 个文本文件的 CRLF 正常化为 LF；已逐项确认暂存内容仅有这一换行差异，没有其他改写。没有其他目标文件冲突；既有文档和用户文件均保留。临时下载包与解包目录位于仓库外，未纳入提交；清理操作及收窄为逐文件删除、仅移除空目录的方案均被自动审批检查拒绝，返回 `blocked by policy`，因此保留现场，需用户另行清理本次 TEMP 下的 `PolyxiaFlutterImport-*` 目录。

| 源文件分组 | Artifact 数量 | 本次新增数量 |
| --- | ---: | ---: |
| 根目录配置、README、依赖清单与锁文件 | 7 | 6（已有 `.fvmrc` 跳过） |
| `android/` | 19 | 19 |
| `windows/` | 18 | 18 |
| `lib/` | 1 | 1 |
| `test/` | 1 | 1 |
| 合计 | 46 | 45 |

保留 `.gitignore`、`.metadata`、Android / Windows 的隐藏忽略文件及 `pubspec.lock`。Gradle 缓存、`local.properties`、临时插件配置及官方忽略的 Gradle wrapper 运行文件不属于此次源文件导出；未手工仿造或补造平台模板。

## 3. 导入后的静态 Review

- 工程位于仓库根目录，项目名为 `polyxia_banner_data_manual_editor`；Android Gradle / Manifest / Kotlin 入口和 Windows CMake / runner / 资源文件存在。
- `pubspec.yaml` 使用 Flutter SDK、官方模板的 `cupertino_icons`、`flutter_test` 和 `flutter_lints`；`publish_to: none`，Dart 约束为 `^3.13.5`。保留官方生成的 `pubspec.lock`，托管依赖指向公开 `pub.dev` 并记录内容哈希；本次未新增第三方依赖或重解锁依赖。
- `.gitignore` 保留官方缓存、IDE 与构建产物忽略规则，`pubspec.lock`、`.metadata` 和 `.fvmrc` 纳入版本管理。
- `lib/main.dart` 仍为官方 Counter 演示页面；`test/widget_test.dart` 使用正确的包导入并验证计数器从 0 增加至 1。此次未修改页面、测试、业务功能或模板依赖。
- Android namespace / applicationId 当前为 `io.github.sirarikako.polyxia_banner_data_manual_editor`；模板 release 仍使用 debug 签名配置。它们属于开发阶段配置，未确认正式发布身份与签名方案。
- Windows 程序名为 `polyxia_banner_data_manual_editor.exe`；资源中的 ProductName / FileDescription / InternalName 为 `polyxia_banner_data_manual_editor`，CompanyName 为 `io.github.sirarikako`。正式显示名称、发布身份与打包方案尚待后续确认；本次不配置 MSIX。

本次仅导入官方工程、替换临时工作流及更新本记录。提交前已核查敏感信息、实际 Git Diff、隐藏文件和生成物范围；`git diff --cached --check` 通过，8 个 XML 文件可解析，8 个缓存 / 本地配置示例路径被正确忽略，5 个必要配置路径未被忽略。工作流 YAML 语法和结构已人工审查，触发条件、权限、命令与缓存配置另经脚本断言检查，两个内嵌 Python 脚本通过 AST 语法检查；这些静态检查不能替代 GitHub 执行。

## 4. 正式快速 CI

新增 [`.github/workflows/01-ci.yml`](../.github/workflows/01-ci.yml)，采用以下契约：

- `pull_request` 目标为 `main`，以及 `push` 到 `main`；推送 `codex/flutter-bootstrap` 本身不会触发该工作流。后续经用户授权推送并创建面向 `main` 的 PR 后，才验证导入后的正式代码。
- 使用 `ubuntu-latest`、20 分钟 Job 时限、`contents: read`，checkout 不保留凭据；不使用 `pull_request_target`、仓库 Secret、AI 凭据或私有数据，不运行 AI Agent、不写入仓库。
- 从 `.fvmrc` 读取完整版本，拒绝浮动版本；通过 `subosito/flutter-action@v2` 安装 stable SDK，核对实际 Flutter 版本及渠道并记录 Flutter / Dart 信息。
- Flutter SDK 缓存按 OS、架构和 `.fvmrc` 隔离；pub 缓存额外包含锁文件哈希。缓存只保存 SDK / pub 包，不保存整个工作区或凭据。
- 依次执行 `flutter pub get --enforce-lockfile`、`dart format --output=none --set-exit-if-changed .`、`flutter analyze --no-pub`、`flutter test --no-pub`，最后检查已跟踪源码无变化。锁文件不一致时失败，不自动更新提交；`--enforce-lockfile` 的作用见 [Dart pub get 文档](https://dart.dev/tools/pub/cmd/pub-get)。
- 记录事件 SHA、PR head SHA、实际 checkout SHA，以及初始 / 最终磁盘和相关缓存 / 输出目录占用。PR 默认检测合并测试提交，不能把 PR head SHA 与实际受测 SHA 混为一谈。
- 不执行 Android / Windows 完整构建、不上传构建包、不发布 Release、不自动提交或合并；任一必要检查失败即保留失败状态。

`02-build.yml` 和 `03-release.yml` 尚未建立。工作流的静态审查不等于 GitHub 实际运行验证。

## 5. 分层验收状态

| 验证项 | 当前状态与证据 |
| --- | --- |
| 官方模板云端 analyze | 通过；上述初始化 Run 执行 `flutter analyze --no-pub`，无问题 |
| 官方模板云端 Widget test | 通过；上述 Run 的 1 个 Counter smoke test 成功 |
| 官方模板云端 format | 通过；上述 Run 检查 2 个 Dart 文件，0 个变更 |
| Artifact 与导入完整性 | 46 / 46 清单哈希匹配；45 个新增文件复制后再次匹配；已有版本文件保持原样 |
| 本次临时下载清理 | **未完成，自动审批检查拒绝清理操作**；文件仍在仓库外，未纳入提交 |
| 导入后的本地静态 Review | 通过；检查平台配置、依赖、忽略规则、文件范围、敏感信息、工作流配置与 Git Diff |
| 本地 Flutter analyze / test / format | **未执行，本地无 Flutter SDK** |
| 导入后正式提交的 `01-ci.yml` | **未执行，尚未推送或创建 PR**；模板历史测试不能替代该提交的 CI |
| 最终代码验收 | **待当前提交 CI**；此次仅完成工程导入和配置静态审查 |
| Windows / Android 云端完整构建 | **未执行** |
| Windows / Android 实机验收 | **未执行** |

## 6. 后续边界

本次按用户授权只建立本地提交，不推送、不创建 PR、不合并 `main`。后续可在得到授权后推送 Feature Branch、创建 PR，检查对应提交的 `01-ci.yml` 实际结果；之后再单独安排最小应用主页开发。

用户明确允许 Codex 完成官方文件导入和 CI 配置审查，本次 **DSH 开发调用 0 次，返工 0 轮**。后续业务实现仍由本地 DSH 执行，Codex 独立 Review；本地与 CI 返工共享最多 3 轮的规则不变。缺少本地 SDK 时继续如实记录未执行项，不降低验收标准，不让 DSH 手工重造 Flutter 平台模板。
