# 按需 Android / Windows 云端构建（02-build）

本文说明 `.github/workflows/02-build.yml` 的实现契约、使用方式、产物结构与验证边界。上层方针见 [CI、构建与发布](ci-build-release.md)，协作硬性规则见 [AGENTS.md](../AGENTS.md)，Review 使用 [检查清单](agent-review-checklist.md)。

当前实现只新增 `02-build.yml`、临时验证调用器和本文档，不修改 Flutter 源码、`pubspec` / `.fvmrc` / 锁文件、Android / Windows 模板、`01-ci.yml` 或四份协作规范。临时验证调用器只进入 `codex/cloud-build-validation`，正式 PR 不包含它。本地没有 Flutter SDK，因此本文所述云端构建尚未在本地执行；实际 GitHub Actions 双平台运行由 Codex 在提交后验证。

## 1. 入口和输入

`02-build.yml` 只有两个入口，没有 `push`、`pull_request`、定时或发布触发。GitHub Actions UI 的人工触发入口只展示默认分支上存在的工作流；当前功能分支尚未合入 `main` 时，首次验证不能依赖 `workflow_dispatch`，必须使用 `codex/cloud-build-validation` 分支的临时 `workflow_call` 调用器（见第 12 节）。`source_ref` 的 `main` 默认值只是待构建源 ref，与工作流文件位于哪个分支无关。

| 入口 | 用途 | `platform` | `source_ref` |
| --- | --- | --- | --- |
| `workflow_dispatch` | 人工按需构建 | `choice`：`android` / `windows` / `both`，默认 `android` | 必填字符串，默认 `main` |
| `workflow_call` | 后续 `03-release.yml` 等复用 | `string`，必填 | `string`，必填，无默认值 |

两个入口共用同一个 `resolve` job。它严格校验：

- `platform` 只接受精确的小写 `android`、`windows`、`both`，其他值立即失败。
- `source_ref` 必须是本仓库中存在的分支、Tag 或完整 40 位十六进制提交 SHA。
- 支持 `refs/heads/...`、`refs/tags/...` 显式形式；同名分支和 Tag 同时存在时视为歧义并失败，需改用显式形式或完整 SHA。
- 拒绝 `HEAD~1` 等 revision 表达式、空值、首尾空白、超长值、非法 ref 字符和 40 位但不存在于本仓库的对象。
- 分支名优先解析 `refs/remotes/origin/...`，必要时回退到当前检出分支的 `refs/heads/...`；Tag 经 `^{commit}` 解引用，附注 Tag 也会落到提交。
- 只有解析结果通过 `git cat-file -t` 确认为 `commit` 后，才输出 40 位小写 SHA。

解析结果通过 job output `source_sha` 传给两个平台 job。平台 job 不再读取分支最新值。

## 2. Job 结构与钉住提交

```
resolve
  ├── android  (仅 platform=android/both)
  ├── windows  (仅 platform=windows/both)
  └── summary  (if: always())
```

- `android` 和 `windows` 只依赖 `resolve`，彼此没有依赖，不使用 matrix，不设置 `concurrency` 互相取消，不使用 `continue-on-error`。
- 两个平台 job 都用 `actions/checkout` 的 `ref: ${{ needs.resolve.outputs.source_sha }}` 检出同一个 SHA，并在构建前用 `git rev-parse HEAD` 再次比对；不一致立即失败。
- 所有 checkout 都设置 `persist-credentials: false`。工作流顶层只有 `permissions: contents: read`。
- 超时：`resolve` 10 分钟、Android 45 分钟、Windows 60 分钟、汇总 5 分钟。

## 3. Flutter、JDK 与构建命令

- `.fvmrc` 是 Flutter 版本的唯一来源，当前固定 `3.47.7`，`channel: stable`。工作流通过 `subosito/flutter-action` 的 `flutter-version-file: .fvmrc` 安装，不在 YAML 里另写版本号。
- 安装后读取 `flutter --version --machine`，校验 `frameworkVersion` 等于 `.fvmrc`、`channel` 等于 `stable`，并把 framework、channel、Dart SDK、engine revision 和 `dart --version` 写入日志与 job summary。
- Android 使用 `ubuntu-latest`，`actions/setup-java@v4` 安装 Temurin JDK 17，并记录 `java -version` / `javac -version`。
- Windows 使用 `windows-latest`，使用 Runner 已安装的 Visual Studio / Windows SDK 工具链；Flutter 构建后、ZIP 打包前按第 6 节从已安装 VS 的官方 x64 VC++ Redistributable CRT 目录复制运行库。
- 两个平台都先执行 `flutter pub get --enforce-lockfile`，再执行：
  - Android：`flutter build apk --release --no-pub`
  - Windows：`flutter build windows --release --no-pub`
- 所有原生命令调用后立即检查 `$LASTEXITCODE` 并 `throw`，不依赖 PowerShell 的 `$ErrorActionPreference` 单独兜底。

## 4. 缓存边界

缓存键都带 `02` 前缀，避免改动或覆盖 `01-ci.yml` 已声明的缓存契约。

| 缓存 | 路径 | 键边界 |
| --- | --- | --- |
| Flutter SDK | 由 `flutter-action` 管理 | `flutter-02-sdk-<runner.os>-x64-<hash(.fvmrc)>` |
| Pub cache | 由 `flutter-action` 管理 | `flutter-02-pub-<runner.os>-x64-<hash(.fvmrc, pubspec.lock)>` |
| Gradle（仅 Android） | `~/.gradle/caches`、`~/.gradle/wrapper` | `gradle-02-<runner.os>-<hash(.fvmrc, pubspec.lock, Android Gradle 配置, gradle-wrapper.properties)>` |

- 不缓存整个工程、`build/`、`android/.gradle`、凭据、debug keystore、签名密钥或 `key.properties`。
- 缓存未命中时按正常流程下载并构建，不把缓存当作发布产物。
- Android wrapper（`gradlew`、`gradlew.bat`、`gradle-wrapper.jar`）在模板 `.gitignore` 中，由 Flutter 工具按需从 SDK 缓存注入；工作流不修改模板，也不在仓库内提交这些文件。若 Flutter 未能生成 wrapper，构建会失败并需报告，不用工作流改写模板来绕过。

## 5. Android 产物

- 构建路径：`build/app/outputs/flutter-apk/app-release.apk`。
- 上传前检查文件存在且非空，并校验 `android/app/build.gradle.kts` 仍使用模板的 debug signing 配置；如果签名配置改变，构建失败而不是继续把产物描述成测试签名。
- Artifact 名称：`android-apk-<40位source_sha>-run<run_id>-attempt<run_attempt>`。
- Artifact 内文件：
  - `polyxia-banner-data-manual-editor-android-<source_sha>-run<run_id>-attempt<run_attempt>.apk`
  - `build-manifest.json`
  - 上述 APK 的 `.sha256` 校验文件
- **Android APK 只是 debug 签名的测试产物**，不是正式签名包。云端构建成功不等于 Android 真机或模拟器验证通过，也不代表用户验收通过。

## 6. Windows 产物与 ZIP 完整性

- 运行目录：`build/windows/x64/runner/Release`。
- 打包前从 Runner 已安装的 Visual Studio 定位官方、允许再分发、匹配 x64 的 VC++ Redistributable CRT：
  - 使用标准安装位置的 `vswhere.exe`（`Microsoft Visual Studio\Installer\vswhere.exe`）执行 `-latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath` 定位 VS；找不到 `vswhere` 或 VS 时立即失败。
  - 在 `<VS>\VC\Redist\MSVC` 下按版本降序检查 `14.*` 目录，再在 `x64\Microsoft.VC14*.CRT` 中选择同时包含 `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll` 且三者非空的目录；没有合法候选时 `throw`。
  - 复制上述 3 个必需 DLL 及所选 CRT 目录内其余 `.dll` 运行库。每个文件先读取 PE 头确认 x64（拒绝 x86 / ARM），复制后比对源文件与目标文件的长度和 SHA256。
  - 只使用已安装 VS 的官方可再分发目录；不从任意系统目录复制，不下载第三方 DLL，不复制 debug / x86 / ARM 版本，不静默跳过或假定用户已安装运行库。
- 上述 3 个 DLL 的要求与 [Flutter 官方 Windows ZIP 打包说明](https://docs.flutter.dev/platform-integration/windows/building#building-your-own-zip-file-for-windows) 一致。
- 打包前再次强制检查 3 个 DLL 存在且非空；打包后除一对一校验全部 Release 文件外，再显式确认这 3 个 DLL 已进入 `release_files` 和 ZIP。
- ZIP 包含该目录下全部文件（不只 exe），至少强制校验：
  - 从 `windows/CMakeLists.txt` 读取的 `BINARY_NAME` 对应 `.exe`
  - `flutter_windows.dll`
  - `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll`
  - `data/icudtl.dat`
  - `data/app.so`（AOT 运行文件）
  - `data/flutter_assets/` 下至少一个文件
- 打包后重新打开 ZIP 逐项验证：
  1. ZIP 文件条目集合与 Release 目录文件集合一一对应，数量相等；
  2. 每个条目非空，长度与源文件一致；
  3. 每个条目内容 SHA256 与源文件及 manifest 记录一致；
  4. 拒绝绝对路径、盘符路径、`..` 路径、重复条目和空条目。
- `build-manifest.json` 包含 `release_files` 完整清单（相对路径、字节数、SHA256）和 ZIP 的 `final_artifact`，可直接下载后独立比对。
- manifest 的 `vc_runtime` 记录可信来源（VS 安装路径、`Microsoft.VC14*.CRT` 目录、Redistributable 版本、x64 架构）、3 个必需文件名及每个已复制 DLL 的长度和 SHA256；日志与 summary 同步记录来源和版本。
- Artifact 名称：`windows-release-zip-<40位source_sha>-run<run_id>-attempt<run_attempt>`。
- Windows 构建未配置文件签名，manifest 和 summary 会明确标注 unsigned。云端构建成功不等于 Windows 实机验证通过。

## 7. Artifact 命名、保留与失败行为

- 两个上传步骤都使用明确的 `path`：
  - `artifacts/android`
  - `artifacts/windows`
- 文件名和 Artifact 名都包含平台、完整 40 位 SHA、`github.run_id`、`github.run_attempt`。
- 上传统一使用 `retention-days: 7` 和 `if-no-files-found: error`。仓库/组织策略必须允许 7 天；若策略限制导致上传失败，应保留失败状态，不能静默改用默认保留期。
- 上传步骤没有 `if: always()`；构建失败时不会上传看似成功的旧包或空包。上传失败本身会使 job 失败。
- 每个平台的 `build-manifest.json` 至少包含：仓库、源 SHA、源 ref、平台、应用版本、Flutter/Dart 版本、run/attempt、构建耗时、签名性质、最终文件大小/SHA256；Windows 另含完整文件清单和 ZIP 校验说明。
- `.sha256` 文件采用 `sha256sum` 风格：`<小写哈希><两个空格><文件名>`。

## 8. 磁盘、缓存、耗时与 summary

- 每个平台在初始化、构建前、构建后记录磁盘总量/可用空间；构建前和构建后记录 Flutter SDK、Pub cache、Gradle cache（Android）和 `build/` 大小。
- `flutter pub get` 与 `flutter build` 都记录耗时。即使原生命令失败，`finally` 也会写日志/summary 耗时，然后继续抛出失败，不吞掉失败状态。
- 最终 APK / ZIP 的大小和 SHA256 写入日志、summary 和 manifest。
- Android 日志和 summary 明确注明 debug 签名测试 APK；两个平台的 summary 都注明“云端成功不等于实机验证”。

## 9. 汇总 job 的失败语义

`summary` 在 `if: always()` 下运行，读取 `resolve`、`android`、`windows` 的结果：

- `platform=android`：Android 必须 `success` 且产出 artifact 名；Windows 必须是 `skipped`。
- `platform=windows`：Windows 必须 `success` 且产出 artifact 名；Android 必须是 `skipped`。
- `platform=both`：两个平台都必须 `success` 且都有 artifact 名。
- 未选平台如果不是 `skipped`（例如错误地运行了）视为异常并失败。
- 解析失败导致 `platform` 为空或非法时，汇总也会失败。
- 任一已选平台失败，汇总抛错，整次 workflow 为失败；不会因为另一个平台绿灯或汇总 job 成功而掩盖。

汇总 job 只做结果判定和 Markdown summary，不下载、不重新打包、不改变平台产物。

## 10. `workflow_call` 输出

供后续 `03-release.yml` 复用：

| 输出 | 含义 |
| --- | --- |
| `source_sha` | 本次实际构建的不可变 40 位提交 SHA |
| `android_artifact` | Android Artifact 名称；未选择 Android 时为空 |
| `windows_artifact` | Windows Artifact 名称；未选择 Windows 时为空 |

调用示例（调用方仍需自行提供最小权限，且不能扩大被调用工作流权限）：

```yaml
jobs:
  build:
    uses: sirarikako/PolyxiaBannerData.ManualEditor/.github/workflows/02-build.yml@<40位提交SHA>
    with:
      platform: both
      source_ref: <40位提交SHA>
```

## 11. 安全边界

- 只有 `contents: read`；没有 Release 写权限、没有 `secrets`、没有 AI Agent 或 AI 凭据。
- 所有 checkout `persist-credentials: false`，不把 Token 留在工作区。
- `inputs` 只通过 `env:` 或 action input 传递；所有 `run:` 脚本内没有 `${{ inputs.* }}` 插值，避免 shell 注入。
- 解析 job 对 ref 做白名单和 Git 对象校验，拒绝 revision 表达式和可疑字符。
- 不缓存签名密钥、keystore、`key.properties`、Token 或凭据；不向日志打印环境变量值或完整认证配置。
- Android 沿用模板 debug 签名，不新增正式签名密钥；Windows 不签名。工作流不创建 Release、不推送 Tag、不修改仓库内容。

## 12. 首次验证与临时调用器

`02-build.yml` 当前只在功能分支，未进入默认分支 `main`。GitHub Actions UI 只在默认分支上展示 `workflow_dispatch` 人工触发入口，因此本任务的首次验证不能建立在 `workflow_dispatch` 上，而是通过独立验证分支上的临时 `workflow_call` 调用器触发：

1. 先在正式分支 `codex/cloud-build` 提交并推送 `02-build.yml` 和本文档，得到包含被调用工作流的正式提交 SHA。
2. Codex 再从该提交切出独立验证分支 `codex/cloud-build-validation`，只在该分支加入 `.github/workflows/02-build-validation.yml`。
3. 把调用器中两个全 `0` 占位 SHA（`uses: .../02-build.yml@<SHA>` 与 `source_ref`）都替换为**同一个正式提交 SHA**，然后提交并推送验证分支。禁止推送仍含占位 SHA 的调用器；占位调用会因 ref 不存在而失败。
4. 验证分支的 `push` 触发调用器，以 `platform: both` 验证同一正式提交的 Android 与 Windows 构建。
5. 验证后移除临时调用器；正式 PR 只包含 `02-build.yml` 和本文档，不包含调用器。不修改 `main` 或 `01-ci.yml` 的快速 CI 触发，也不要求安装或使用 `gh`。

调用器的触发条件仅为 `push` 到 `codex/cloud-build-validation` 且推送包含 `.github/workflows/02-build-validation.yml` 的变更；最小 `contents: read`，不使用 secrets，不调用 AI。调用器中的 workflow ref 与 `source_ref` 必须一致，并且都指向包含 `02-build.yml` 的正式提交。

## 13. 使用方式与排查

首次验证按第 12 节使用验证分支的临时调用器，不要等待 `workflow_dispatch`：此时工作流文件还不在默认分支，Actions UI 不会提供人工触发入口。

`02-build.yml` 进入默认分支后，可在 GitHub Actions 页面选择 `02 - On-demand builds` -> `Run workflow`，选择工作流文件所在 ref，再填写 `platform` 和 `source_ref`。`source_ref` 默认 `main` 只是待构建源 ref 的默认值，可改为本仓库分支、Tag 或完整 40 位 SHA。命令行 `gh workflow run` 只是可选方式，本任务不要求安装或使用 `gh`。

常见失败与含义：

| 现象 | 原因/处理 |
| --- | --- |
| `Invalid platform` | `workflow_call` 传入了非 `android`/`windows`/`both` 值 |
| `source_ref ... was not found` | 分支/Tag/SHA 不在本仓库，或拼写错误 |
| `ambiguous (both a branch and a tag)` | 同名分支和 Tag；改用 `refs/heads/...`、`refs/tags/...` 或完整 SHA |
| `does not match resolved source` | checkout 未落到解析 SHA，属于严重异常，不要重试掩盖 |
| `vswhere.exe was not found` / `No usable official x64 VC++ redistributable` | Runner 上没有可用的 VS/VC++ x64 CRT 合法来源；构建失败，不从系统目录或第三方来源补 DLL |
| `Required VC++ runtime DLL is missing/empty` | Release 目录缺少 `msvcp140.dll`、`vcruntime140.dll`、`vcruntime140_1.dll` 或为空；不会生成 ZIP |
| `VC++ runtime DLL is not x64` | 选中的 CRT 不是 x64（例如 x86/ARM/debug），拒绝打包 |
| `Required Windows Release file is missing` | Release 运行目录缺少 exe/DLL/ICU/AOT/assets，ZIP 不完整 |
| `ZIP ... mismatch` | 打包或文件在打包期间变化，产物不可信，构建失败 |
| `Platform resolution failed` / 汇总失败 | 解析 job 失败或非法输入；查看 `resolve` 日志 |

缓存未命中不是失败；网络、Runner 镜像、Android SDK 组件下载和 Visual Studio 工具链属于基础设施条件，失败时先报告，不通过改业务代码或放宽校验绕过。

## 14. 验证边界

本次实现本地只做 YAML/输入/脚本语法、解析逻辑、失败汇总和隔离假产物的 ZIP / manifest / VC++ 运行库校验；本地没有 Flutter SDK，未执行 Flutter 构建、`flutter analyze`、`flutter test` 或任何真机构建。

Windows 隔离验证使用 6 个非空占位运行文件、假 VS 目录树和假 `vswhere`，执行提取后的实际复制与打包脚本，共 11 个场景：正例（3 个必需 DLL + 2 个关联 DLL 被复制并进入 `release_files` / ZIP）、3 个必需 DLL 分别缺失、空 DLL、空源 DLL、无 Redistributable 目录、无 `vswhere`、x64 目录中的 x86 DLL 被拒绝、debug CRT DLL 被拒绝、最新版本 CRT 不完整时回退到次新完整版本。这些场景验证选择、复制、manifest 和 ZIP 一致性，不代表 Windows 真实构建或实机成功。

正式 CI 和实际 Android / Windows 云端双平台由 Codex 在提交后验证；云端成功仍不代表 Windows / Android 实机验收通过。
