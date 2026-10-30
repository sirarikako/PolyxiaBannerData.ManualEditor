import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'manual_data.dart';

void main() => runApp(const ManualEditorApp());

class ManualEditorApp extends StatelessWidget {
  const ManualEditorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Polyxia Manual Editor',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6579bb)),
    ),
    home: const EditorHome(),
  );
}

class EditorHome extends StatefulWidget {
  const EditorHome({super.key});
  @override
  State<EditorHome> createState() => _EditorHomeState();
}

class _EditorHomeState extends State<EditorHome> {
  final repo = Repository();
  final phase = TextEditingController(text: '1');
  final matchName = TextEditingController();
  final editName = TextEditingController();
  final start = TextEditingController();
  final end = TextEditingController();
  final itemName = TextEditingController();
  final itemId = TextEditingController();
  final source = TextEditingController();
  final outputPath = TextEditingController();
  Game game = Game.genshin;
  Catalog? catalog;
  ManualDocument? document;
  GachaBanner? selected;
  String? version;
  String? error;
  String poolType = 'character_event';
  bool upcoming = false, busy = false, changed = false;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    loadGame();
  }

  @override
  void dispose() {
    generation++;
    repo.dispose();
    for (final c in [
      phase,
      matchName,
      editName,
      start,
      end,
      itemName,
      itemId,
      source,
      outputPath,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void notify(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> loadGame() async {
    if (changed) {
      notify('请先导出当前修改');
      return;
    }
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
      catalog = null;
      document = null;
      selected = null;
      version = null;
    });
    try {
      final data = await repo.catalog(game);
      if (!mounted || request != generation) return;
      setState(() {
        catalog = data;
        busy = false;
      });
      if (data.versions.isNotEmpty) await loadVersion(data.versions.first);
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          busy = false;
          error = '读取失败：$e';
        });
      }
    }
  }

  Future<void> loadVersion(String value) async {
    if (changed) {
      notify('请先导出当前修改');
      return;
    }
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
      version = value;
      document = null;
      selected = null;
    });
    try {
      final manual = await repo.manual(game, value);
      if (!mounted || request != generation) return;
      setState(() {
        document = manual;
        busy = false;
        final list = catalog?.forVersion(value) ?? [];
        selected = list.isEmpty ? null : list.first;
      });
      clearForm();
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          busy = false;
          error = '人工数据加载失败：$e';
        });
      }
    }
  }

  void clearForm() {
    for (final c in [editName, start, end, itemName, itemId, source]) {
      c.clear();
    }
    if (selected != null) {
      phase.text = (selected!.phase ?? 1).toString();
      matchName.text = selected!.title;
      if (selected!.poolType.isNotEmpty) poolType = selected!.poolType;
    }
  }

  void addPatch() {
    try {
      final doc = document;
      if (doc == null) throw const FormatException('尚未加载人工数据');
      final patch = makePatch(
        name: editName.text,
        start: start.text,
        end: end.text,
        itemName: itemName.text,
        itemId: itemId.text,
        sourceUrl: source.text,
      );
      if (upcoming) {
        final number = int.tryParse(phase.text);
        if (number == null || number < 1 || number > 9) {
          throw const FormatException('期数应为 1～9');
        }
        final match = <String, dynamic>{'phase': number, 'poolType': poolType};
        if (game == Game.starrail) {
          match['bannerName'] = requiredText(matchName.text, '卡池名称');
        } else if (matchName.text.trim().isNotEmpty) {
          match['bannerName'] = matchName.text.trim();
        }
        doc.addUpcoming(match, patch);
      } else {
        if (selected == null) throw const FormatException('请选择已发布卡池');
        doc.addExisting(selected!, patch);
      }
      setState(() => changed = true);
      notify('已加入草稿，请核对 JSON');
    } catch (e) {
      notify('编辑失败：$e');
    }
  }

  Future<void> copy() async {
    try {
      document!.validate();
      await Clipboard.setData(ClipboardData(text: document!.formatted));
      notify('已复制 ${document!.filename}');
    } catch (e) {
      notify('校验失败：$e');
    }
  }

  Future<void> save() async {
    try {
      final doc = document!;
      doc.validate();
      final path = outputPath.text.trim();
      if (path.isEmpty || !File(path).isAbsolute) {
        throw const FormatException('请输入绝对文件路径');
      }
      final target = File(path);
      if (await target.exists()) throw const FormatException('目标文件已存在，禁止覆盖');
      await target.writeAsString(doc.formatted, flush: true);
      if (!mounted) return;
      setState(() => changed = false);
      notify('已导出 $path');
    } catch (e) {
      notify('导出失败：$e');
    }
  }

  Widget input(
    String title,
    TextEditingController controller, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: title,
        hintText: hint,
        isDense: true,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final versions = catalog?.versions ?? [];
    final banners = catalog?.forVersion(version ?? '') ?? [];
    final types = game == Game.genshin
        ? ['character_event', 'character_event_2', 'weapon_event', 'chronicled']
        : [
            'character_event',
            'light_cone_event',
            'collab_character',
            'collab_light_cone',
          ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polyxia Manual Editor'),
        actions: [
          if (changed) const Icon(Icons.warning_amber),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: busy || changed ? null : loadGame,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<Game>(
              segments: Game.values
                  .map((g) => ButtonSegment(value: g, label: Text(g.label)))
                  .toList(),
              selected: {game},
              onSelectionChanged: busy || changed
                  ? null
                  : (values) {
                      setState(() {
                        game = values.first;
                        poolType = 'character_event';
                        upcoming = false;
                      });
                      loadGame();
                    },
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 12),
                  if (versions.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey('version-${game.key}-$version'),
                      initialValue: versions.contains(version) ? version : null,
                      decoration: const InputDecoration(
                        labelText: '版本',
                        border: OutlineInputBorder(),
                      ),
                      items: versions
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) loadVersion(value);
                            },
                    ),
                  const SizedBox(height: 12),
                  if (document != null) ...[
                    Text(
                      '人工文件：${document!.filename}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('existing 已发布'),
                        ),
                        ButtonSegment(value: true, label: Text('upcoming 新池')),
                      ],
                      selected: {upcoming},
                      onSelectionChanged: (values) {
                        setState(() {
                          upcoming = values.first;
                          clearForm();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!upcoming && banners.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: ValueKey('banner-${selected?.id}'),
                        initialValue: banners.any((b) => b.id == selected?.id)
                            ? selected!.id
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '已发布卡池',
                          border: OutlineInputBorder(),
                        ),
                        items: banners
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  '${b.title}  [${b.id}]',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() {
                              selected = banners.firstWhere((b) => b.id == id);
                              clearForm();
                            });
                          }
                        },
                      ),
                    if (upcoming) ...[
                      input('第几期（1～9）', phase),
                      DropdownButtonFormField<String>(
                        key: ValueKey('type-${game.key}-$poolType'),
                        initialValue: types.contains(poolType)
                            ? poolType
                            : types.first,
                        decoration: const InputDecoration(
                          labelText: '卡池类型',
                          border: OutlineInputBorder(),
                        ),
                        items: types
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => poolType = v);
                        },
                      ),
                      input('定位卡池名称（星铁必填）', matchName),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      '只填写需要修正的字段，留空表示不修改',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    input('卡池中文名称', editName),
                    input(
                      '开始时间 +08:00',
                      start,
                      hint: '2026-10-30T18:00:00+08:00',
                    ),
                    input('结束时间 +08:00（V1 独占边界）', end),
                    input('物品中文名称', itemName),
                    input('官方物品 ID（未知可留空）', itemId),
                    input('补充来源 HTTPS 地址', source),
                    FilledButton.icon(
                      onPressed: addPatch,
                      icon: const Icon(Icons.add),
                      label: const Text('加入人工补丁'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'upcoming ${document!.upcoming.length} 条，existing ${document!.existing.length} 条',
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      document!.formatted,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('校验并复制 JSON'),
                    ),
                    input('导出完整绝对路径（不覆盖已有文件）', outputPath),
                    FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.save),
                      label: const Text('导出 JSON'),
                    ),
                    const SizedBox(height: 20),
                    const Text('只生成本地 JSON，不修改正式 V1 或自动提交 GitHub'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
