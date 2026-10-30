# PolyxiaBannerData.ManualEditor

Flutter Windows / Android 公共卡池人工编辑器。读取 [PolyxiaBannerData](https://github.com/sirarikako/PolyxiaBannerData) 的公开 v1 卡池信息以及人工版本补丁，输出符合人工输入格式的 JSON；**不直接修改正式 V1，也不向 GitHub 写入**。

## P0 + P1（Windows 优先验收）

- 原神、星铁切换，在线读取公开 V1，按版本和已发布卡池筛选。
- `existing` 用已发布内部 ID 定位；`upcoming` 通过期数 / 池种 / 名称生成待发布候选匹配。
- 名称、服务器时间、官方 ItemID 和附加 HTTPS 来源编辑；仅填写需要覆盖的字段。
- 加载远端已有人工文件，真实 404 时生成空草稿；其他网络、格式错误明确显示失败。
- JSON 检查、预览、剪贴板复制、指定绝对路径导出，不覆盖已存在文件。

**已知限制**：UP 五星 / 四星列表整体编辑、特殊变种及更多高级 Schema 字段尚未提供图形表单；当前仍可在数据仓库原有人工 JSON 流程中维护。Android 尚未做实机验收，暂时使用复制 JSON；Windows 可指定路径导出。切换游戏或版本前先导出修改。

## Codex Windows 测试

```powershell
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub
flutter run -d windows
```

使用 `.fvmrc` 固定 Flutter 3.47.7，参见 [AGENTS.md](AGENTS.md)。
