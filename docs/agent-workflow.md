# ChatGPT 开发 + Codex 独立测试流程

`AGENTS.md` 为当前规则。旧 Codex → DSH 流程已停用，当前任务不使用 DSH Headless、模型代理或其自动返工次数预算。

## A. ChatGPT 开发

1. 读取最新 `main`、`AGENTS.md`、相关源码 / Schema 和 CI 约束。
2. 创建独立 `feature/<任务>` 分支。记录起始 SHA；只在约定范围内修改代码与必要测试。
3. 优先用公开、可复现的最小测试数据；不要拉取私有数据或要求用户提供 Token。
4. 静态检查实际改动，按可用环境运行测试；无法执行 Flutter 时不能假称已通过。
5. 以当前功能分支提交 PR，描述功能、验证、风险、未验证的环境和可供 Codex 执行的命令；默认不合并。

## B. Codex 在 Windows 独立验收

1. 先检查原工作区，避免覆盖未提交工作；只读检查当前 SHA，然后安全检出待测试分支。
2. 核对 `.fvmrc` 固定版本、`pubspec.lock`，执行：
   - `flutter pub get --enforce-lockfile`
   - `dart format --output=none --set-exit-if-changed .`
   - `flutter analyze --no-pub`
   - `flutter test --no-pub`
3. 根据改动进行 Windows `flutter run -d windows` 功能验收；必须使用测试目录、测试导出路径，不触碰正式数据。
4. 查看关联 GitHub PR 的 CI，确认受测提交 SHA / 失败步骤；按需触发已有 `02-build.yml` 的 Windows 构建。
5. 记录具体失败操作、实际 / 预期结果、错误日志和测试 SHA。除用户明确另行授权外，Codex 只读检查及运行测试，不修业务代码、不提交、不推送、不合并。
6. Android 环境未就绪时记为“Android 实机未执行”，允许 Windows 阶段验收独立通过，不冒充 Android 实机测试。

## C. 返工和合并

- 将 Codex 报告交回 ChatGPT；ChatGPT 修复本 PR 分支并补充回归测试。
- 每次修复后复验受影响行为与当前提交 CI；不削弱测试、不假造结果。
- 由用户最终验收和决定合并。合并与正式 Release 另行授权。

## 人工数据编辑器专用边界

- 从 PolyxiaBannerData 公开仓库只读取得 V1 卡池与版本人工文件；原仓库不存在人工文件时可创建空格式，网络 / JSON 失败不能悄悄替代成“空数据”。
- `upcoming` 仅定位尚未发布的可信候选；`existing` 仅以当前版本内既有内部 ID 定位。不得互相替代。
- 人工补丁里的数组是整体替换（除 `regions` 按 server 合并）；不能编造物品 ID，未知时用 null。
- P0 / P1 只在本地生成 / 导出人工 JSON，不直接修改正式数据或通过 GitHub API 自动提交。
