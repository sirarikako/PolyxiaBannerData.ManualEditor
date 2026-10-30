# Codex 独立验收检查清单（Windows 优先）

本清单配套 [AGENTS.md](../AGENTS.md)。勾选时区分“通过、失败、未执行、不适用”，未执行不能当作通过。

## 分支与差异
- [ ] 记录 PR、head SHA、相对 main 的实际改动；安全保护现有工作区。
- [ ] 仅修改 P0 / P1 及协作规则范围；无隐含 DSH 依赖、无凭据、无私有数据、无正式 V1 写入。
- [ ] 校验数据模型与最新 `schemas/manual/`：game / format / version / match / id / itemIds / set / regions / sources。
- [ ] 检查异常路径：HTTP 非 200、404、无网络、错误 JSON、空版本、重复 ID / match、损坏人工文件。

## 自动化（独立执行）
- [ ] 核对 `.fvmrc`，Flutter SDK 和 Dart 版本符合固定版本。
- [ ] `flutter pub get --enforce-lockfile`。
- [ ] `dart format --output=none --set-exit-if-changed .`。
- [ ] `flutter analyze --no-pub`。
- [ ] `flutter test --no-pub`；覆盖正常与错误、版本隔离、状态保留、导出字段等。
- [ ] PR 当前提交的 `01-ci.yml` 通过；确认实际受测 SHA，不拿旧 Run 代替。

## Windows 操作
- [ ] `flutter run -d windows` 能启动，不是默认计数器。
- [ ] 选择原神 / 星铁、版本、卡池时显示正确数据；加载等待和失败状态清晰。
- [ ] 已发布池 existing 生成正确 `id` 补丁；未发布池 upcoming 生成正确 `match`。
- [ ] 测试名称、五星 / 四星 UP、Item ID、开始 / 结束时间及来源编辑。
- [ ] 非法日期、ID、数量、URL、重复补丁被阻止；未编辑字段不会误覆盖现有数据。
- [ ] 能检查、复制 JSON；Windows 指定路径导出成功；文件已存在时有明确保护。
- [ ] 使用临时目录，不碰用户真实 JSON；关闭窗口和切换状态无明显卡死。

## 平台与交付
- [ ] Windows 实机结果单独记录（成功 / 失败 / 未执行）。
- [ ] Windows 云端构建（如触发）记录 Run / Artifact / SHA。
- [ ] Android 云端构建状态独立记录（可选）；Android 实机环境未就绪，明确记录“未执行”。
- [ ] 无未处理阻断问题；附复现步骤交 ChatGPT 修复。
- [ ] 不自动修改业务实现、提交 / 推送或合并 PR。
