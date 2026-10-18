# 轻量本地开发与 GitHub 云端 CI、构建、发布方针

本文约定未来工作流的职责与验收证据，不表示工作流已经实现。协作硬性规则见 [AGENTS.md](../AGENTS.md)，自动返工见 [协作流程](agent-workflow.md)，执行时使用 [Review 检查清单](agent-review-checklist.md)。本次仅维护这四份文档，不创建或修改 `.github/workflows/`、`.fvmrc`、SDK 或 Flutter 代码，不推送远端。

## 1. 开发与执行位置

| 环境 | 负责内容 | 边界 |
| --- | --- | --- |
| Windows 11 Hyper-V VM | Codex 设计、调度与 Review；DSH 开发；Flutter / Dart、本地格式与快速测试 | 不擅自安装 Android Studio、NDK、模拟器等大型依赖，不要求本地完整双平台构建 |
| GitHub Ubuntu Runner | Flutter CI、Android APK 构建 | 仅运行确定的检查与构建，不运行 AI Agent |
| GitHub Windows Runner | Windows Release 构建与 ZIP 打包 | 独立平台 Job，不把 Ubuntu 结果当作 Windows 构建证据 |
| Android 真机 | 优先通过 Wi-Fi ADB 调试和验收 | 配对及设备权限按实际条件处理，不把连接成功当作功能验收通过 |
| 宿主机 Android Emulator | 必要时补充 Android 调试 | 使用已有条件；结果单列为模拟器验证，不冒充实机通过 |

Codex 与 DSH 均留在本地协作。Actions 不启动 AI Agent，也不需要 DeepSeek、OpenAI 或其他 AI API 凭据。

## 2. Flutter 版本与资源约束

- `.fvmrc` 是项目 Flutter 版本的统一来源，固定明确版本，本地、CI、Android 和 Windows 构建一致使用；不得悄悄改为浮动 `stable` / `latest`。版本缺失、解析失败或不匹配时报告，不隐式升级。
- FVM 用项目 `.fvmrc` 记录版本；本方针不要求额外安装 FVM，已有工具能读取并使用同一明确版本即可。版本配置依据见 [FVM 官方说明](https://fvm.app/documentation/getting-started/faq)。具体版本在真实 Flutter 项目任务中确定，本次不创建该文件。
- 恢复项目现有依赖与新装大型开发软件是不同操作；前者按任务范围执行，后者不得擅自进行。不要为了让 VM 复现完整构建而安装 Android Studio、NDK 或模拟器。
- Android 与 Windows 分开构建，按需选择平台；普通 PR 默认不运行完整双平台构建。`both` 表示两个独立平台 Job 均需要成功。
- 合理缓存 Flutter SDK / 包依赖及 Android Gradle 依赖。缓存键包含适用的 OS、Flutter 固定版本、依赖锁文件及 Gradle 配置信息，避免平台或版本串用；缓存未命中应可正常构建，不缓存整个工作区、Private 数据、Token 或签名密钥，也不把缓存当作发布产物。
- 在 Runner 初始化、构建前后记录磁盘总量、剩余空间、相关缓存 / 输出目录占用及最终包体大小；不打印敏感路径内容。只清理本次 Job 明确拥有且确认可再生成的临时数据，不为腾空间盲删 SDK、用户数据或验证证据。

## 3. 三个计划工作流的契约

下列名称是未来 `.github/workflows/` 中的计划文件，当前不创建 YAML。

| 工作流 | 触发 | Runner 与任务 | 输出 |
| --- | --- | --- | --- |
| `01-ci.yml` | 面向 `main` 的 PR，以及 push 到 `main` | Ubuntu；format、analyze、test | 可追溯到受测提交的检查结果；不默认完整双平台构建 |
| `02-build.yml` | `workflow_dispatch` / `workflow_call` | Android 用 Ubuntu，Windows 用 Windows；选择 Android、Windows 或 both | APK、Windows Release ZIP；所选平台的 Artifacts 保留 7 天 |
| `03-release.yml` | push `v*` Tag | 验证发布来源后复用 `02-build.yml`；发布 Job 汇总产物 | 新版本 GitHub Release、对应 APK / ZIP 和 SHA256 清单 |

### 01：快速 CI

- 格式检查只判断是否符合规范，不在 CI 自动改写提交；analyze 与 test 必须实际执行，失败保留失败状态。具体命令与目录以未来项目配置为准。
- PR CI 使用 `pull_request` 和最小只读权限，通常仅 `contents: read`，其他权限关闭；不接收仓库 Secret，不访问私有原数据，不用高权限事件执行不受信任的 PR 代码。GitHub 对此风险的说明见 [PR 事件安全文档](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target)。
- 记录 PR head SHA 与实际测试 SHA。PR 的测试对象可能是合并测试提交；本地代码通过或旧提交 CI 通过，不能替代当前受测提交的 CI。

### 02：按需、可复用构建

- 两种入口使用同一平台选择契约，取值为 `android`、`windows`、`both`，拒绝其他值。手动构建明确选择源 ref，再解析并记录不可变提交 SHA；所有平台检出同一 SHA，不能各自取变化中的分支最新值。
- Android Job 只产出约定 APK；Windows Job 打包完整 Release 运行目录为 ZIP，包含运行所需文件，不能只上传可执行文件。所选平台失败时不得将整个构建报告为通过；另一个平台的结果可独立记录。
- Artifact 名称包含平台、提交标识及足以区分 Run 的信息，不混用不同提交或旧 Run 的文件。上传前确认文件存在，缺失不得只发警告后判成功。
- 上传明确设置 `retention-days: 7`，并核对仓库 / 组织策略允许该设置；不能静默沿用默认期限。该选项及策略限制见 [GitHub Artifact 文档](https://docs.github.com/en/actions/tutorials/store-and-share-data)。7 天仅指临时 Actions Artifacts，不是正式 Release 附件保留期。
- 构建流程只需读取源码和上传本次产物，不获得发布 Release 的写权限。若确需签名，签名方案及所需权限应在实施任务中明确，密钥不得入仓、入日志、缓存或产物；不得把测试签名的 APK 描述为已完成正式签名。

### 03：验证来源后发布

1. 仅由 `v*` Tag 触发发布；Tag 命名匹配本身不构成来源验证，也不自动授予本地 Agent 推 Tag 的权限。
2. 解析 Tag 的实际提交，验证来自本公共 App 仓库的可信 `main` 历史，并具有该提交对应的 `01-ci.yml` 成功证据。证据缺失、来源不明、目标不一致或必要检查失败时停止，不用其他提交的绿灯替代。取历史时须有足够信息，不能因浅克隆无法判断便跳过验证。
3. 复用 `02-build.yml`，向构建传入已验证的提交 SHA，正式 Android + Windows 发布选择 `both`。工作流复用使用 `workflow_call`，输入显式传递，不能让被调用方扩大权限；机制依据见 [GitHub 工作流复用文档](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)。
4. 所需平台均成功且产物齐全后，从本次关联 Run 获取确切文件，计算 APK 与 ZIP 的 SHA256，生成随附件发布的清单。校验值针对用户下载的最终 APK / ZIP，不以 Actions Artifact 包装层的摘要代替。
5. Release 记录版本、源提交、构建 Run 及附件。发布 Job 才授予必要的 `contents: write`；前置验证和构建保持最小只读权限，不把发布 Token 或全部 Secrets 传入复用构建。
6. 正式 V1 的既有代码、数据、发布 Tag、Release 和附件受保护，不自动覆盖、删除或替换，不移动旧标签。同名正式 Release 或附件冲突时停止报告，使用新版本发布；不能靠重跑自动覆盖旧资产。

Tag 发布前应由用户或既有明确授权的发布流程完成所需实机和用户验收。Tag 工作流的成功仅证明自动发布步骤成功，不能补写“实机已通过”或“用户已验收”。本次方针不设置实际仓库保护、发布权限或 Secrets，也不声称这些条件已具备。

## 4. 公共仓库与权限边界

- 公共 App 源码仓库与原数据仓库分离。CI 使用合成或明确可公开的最小测试夹具，不 checkout 私有原数据仓库，不把原数据或本地导出数据附入测试日志与产物。
- Token、AI 凭据及私有配置不进入源码、提示词、日志、缓存、APK、ZIP 或 Release；避免使用会整体输出环境与配置的诊断命令。
- PR、构建和发布分开权限。普通 PR 不允许写仓库或发布，不自动合并 PR；不为 CI 失败提升 PR 权限、开放 Secret 或改用高权限事件运行 PR 代码。
- 不通过取消测试、弱化断言、跳过 analyze、放宽发布来源检查或隐藏失败解决 CI。确有代码问题由 DSH 修复，Codex 独立审查并复验。

## 5. CI 返工与分层验收

Codex 在本地读取实际 Run 日志，区分实现、测试、配置问题与基础设施故障；需要代码修复时再调用本地 DSH。**本地 Review 与 CI 返工共享最多 3 轮**，不能在进入 PR、切换平台或换 Run 后重置；例如本地 2 轮后 CI 只剩 1 轮。调用故障、预算耗尽或无法解决时按协作流程停止并报告。

| 状态 | 所需证据 | 不能替代的验证 |
| --- | --- | --- |
| 代码验收通过 | Codex 实际 Diff Review、本地相关测试，以及适用的当前提交 CI 检查 | 不代表 APK / Windows ZIP 已构建或设备可用 |
| 云端构建通过 | 指定提交的所选平台 Job 成功，所需产物完整、可取得 | 不代表 Windows / Android 实机已验收 |
| Windows 实机验收通过 | 目标 Windows 运行环境、产物版本及实际场景结果；注明 VM / 宿主机等环境 | 不能以 Windows Runner 编译成功代替 |
| Android 实机验收通过 | 真实 Android 设备、产物版本、实际场景及结果 | 不能以 APK 构建、ADB 连接或模拟器通过代替 |

PR CI 通过与 `02-build.yml` 的云端构建通过也分别记录。未执行项写“未执行”，不适用项写“不适用”并说明依据；未完成必需项时不得报告完整验收通过。云端结果必须关联源提交和实际产物，用户验收另行记录，待确认时不能替用户宣告通过。

## 6. 后续实施边界

后续获准实施 Actions 时，再检查真实 Flutter 项目、`.fvmrc` 版本、依赖、Runner 条件、仓库权限与保护设置、签名需求和设备可用性，按上述契约创建三个工作流并用实际 Run 验证。本次只有文档一致性、链接、范围与 Diff 检查，不能作为云端运行、发布或实机验证的成功证据，也不增加额外调度脚本、服务或依赖。
