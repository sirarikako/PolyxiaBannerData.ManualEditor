import 'dart:convert';
import 'dart:io';

enum Game {
  genshin('genshin', '原神', 'gi-', 'genshin-v1-overrides-v2'),
  starrail('starrail', '星铁', 'hsr-', 'starrail-v1-overrides-v1');
  const Game(this.key, this.label, this.prefix, this.format);
  final String key, label, prefix, format;
}
const dataRoot = 'https://raw.githubusercontent.com/sirarikako/PolyxiaBannerData/main';

Map<String, dynamic> asObject(Object? x) {
  if (x is! Map<String, dynamic>) throw const FormatException('不是 JSON 对象');
  return x;
}
String requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) throw FormatException('${field}不能为空');
  return value.trim();
}
void validateTime(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+08:00$').hasMatch(value) ||
      DateTime.tryParse(value) == null) {
    throw const FormatException('时间需要 YYYY-MM-DDTHH:mm:ss+08:00');
  }
}
class Banner {
  Banner(this.data);
  final Map<String, dynamic> data;
  String get id => data['id']?.toString() ?? '';
  String get version => data['gameVersion']?.toString() ?? '';
  String get title {
    final names = data['names'];
    return names is Map ? (names['zh-CN']?.toString() ?? id) : id;
  }
  int? get phase => data['phase'] is int ? data['phase'] as int : null;
  String get poolType => data['poolType']?.toString() ?? '';
}
class Catalog {
  Catalog(this.banners);
  final List<Banner> banners;
  factory Catalog.parse(Game game, String input) {
    final data = asObject(jsonDecode(input));
    if (data['game'] != game.key || data['schemaVersion'] != 1 || data['banners'] is! List) {
      throw const FormatException('公开数据版本或游戏不正确');
    }
    final seen = <String>{};
    final list = (data['banners'] as List).map((x) => Banner(asObject(x))).toList();
    for (final b in list) {
      if (!b.id.startsWith(game.prefix) || !seen.add(b.id)) {
        throw const FormatException('卡池 ID 缺失或重复');
      }
    }
    return Catalog(list);
  }
  List<String> get versions {
    final values = banners.map((b) => b.version).where((v) => v.isNotEmpty).toSet().toList();
    values.sort((a,b) => b.compareTo(a));
    return values;
  }
  List<Banner> forVersion(String version) => banners.where((b) => b.version == version && b.phase != null).toList();
}
class ManualDocument {
  ManualDocument(this.game, this.version, {List<Map<String,dynamic>>? upcoming, List<Map<String,dynamic>>? existing})
    : upcoming = upcoming ?? [], existing = existing ?? [];
  final Game game;
  final String version;
  final List<Map<String,dynamic>> upcoming, existing;
  factory ManualDocument.parse(Game game, String version, String input) {
    final obj = asObject(jsonDecode(input));
    if (obj['format'] != game.format || obj['game'] != game.key ||
        obj['locale'] != 'zh-CN' || obj['version'] != version) {
      throw const FormatException('人工文件的 Schema、游戏或版本不匹配');
    }
    List<Map<String,dynamic>> rows(String name) {
      final value = obj[name];
      if (value is! List) throw FormatException('${name}必须是数组');
      return value.map((v) => asObject(v)).toList();
    }
    final doc = ManualDocument(game, version, upcoming: rows('upcoming'), existing: rows('existing'));
    doc.validate();
    return doc;
  }
  String get filename => '${game.key}_$version.json';
  String get formatted => const JsonEncoder.withIndent('  ').convert({
    'format': game.format, 'game': game.key, 'locale': 'zh-CN',
    'version': version, 'upcoming': upcoming, 'existing': existing
  }) + '\n';
  void validate() {
    requiredText(version, '版本');
    final ids = <String>{};
    for (final e in existing) {
      final id = requiredText(e['id'], '内部 ID');
      if (!id.startsWith(game.prefix) || !RegExp(r'^[a-z]+-[0-9]{6}$').hasMatch(id) ||
          !ids.add(id) || e.containsKey('match')) throw const FormatException('existing 的 ID 无效或重复');
      _validatePatch(e);
    }
    final matches = <String>{};
    for (final e in upcoming) {
      final match = asObject(e['match']);
      final phase = match['phase'];
      final type = match['poolType'];
      final allowed = game == Game.genshin
          ? ['character_event','character_event_2','weapon_event','chronicled']
          : ['character_event','light_cone_event','collab_character','collab_light_cone'];
      if (e.containsKey('id') || phase is! int || phase < 1 || phase > 9 ||
          !allowed.contains(type) || (match['version'] != null && match['version'] != version)) {
        throw const FormatException('upcoming 匹配字段无效');
      }
      if (game == Game.starrail) requiredText(match['bannerName'], '卡池名称');
      if (!matches.add(jsonEncode(match))) throw const FormatException('upcoming 匹配重复');
      _validatePatch(e);
    }
  }
  void _validatePatch(Map<String,dynamic> patch) {
    if (patch['status'] != null && !['pending','completed'].contains(patch['status'])) throw const FormatException('状态无效');
    if (!patch.containsKey('set') && !patch.containsKey('itemIds') && !patch.containsKey('addSources')) {
      throw const FormatException('没有修改字段');
    }
    if (patch['set'] != null) {
      final set = asObject(patch['set']);
      final allowed = game == Game.genshin
          ? ['names','featured','regions','gachaTypes','sources','images','fatePointLimit']
          : ['names','featured','regions','gachaTypes','gachaIds','sources','images'];
      if (set.keys.any((x) => !allowed.contains(x))) throw const FormatException('set 包含非法字段');
      if (set['regions'] is List) {
        for (final region in set['regions'] as List) {
          final r = asObject(region);
          requiredText(r['server'], '服务器');
          if (r['startAt'] != null) validateTime(r['startAt'].toString());
          if (r['endAt'] != null) validateTime(r['endAt'].toString());
        }
      }
    }
    if (patch['itemIds'] != null) {
      for (final e in asObject(patch['itemIds']).entries) {
        requiredText(e.key, '物品名称');
        if (e.value != null && (e.value is! String || !RegExp(r'^[1-9][0-9]*$').hasMatch(e.value as String))) {
          throw const FormatException('物品 ID 必须是正整数数字字符串或 null');
        }
      }
    }
    if (patch['addSources'] != null) {
      final sources = patch['addSources'];
      if (sources is! List) throw const FormatException('来源格式错误');
      for (final e in sources) {
        final source = asObject(e);
        requiredText(source['provider'], '来源类型');
        if (source['url'] != null) {
          final uri = Uri.tryParse(source['url'].toString());
          if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) throw const FormatException('来源必须使用 HTTPS');
        }
      }
    }
  }
  void addExisting(Banner banner, Map<String,dynamic> patch) {
    if (banner.version != version || !banner.id.startsWith(game.prefix)) throw const FormatException('卡池版本不符');
    final row = <String,dynamic>{'id': banner.id, 'status':'pending', ...patch};
    final index = existing.indexWhere((e) => e['id'] == banner.id);
    if (index < 0) { existing.add(row); } else { existing[index] = row; }
    validate();
  }
  void addUpcoming(Map<String,dynamic> match, Map<String,dynamic> patch) {
    final row = <String,dynamic>{'match': match, 'status':'pending', ...patch};
    final index = upcoming.indexWhere((e) => jsonEncode(e['match']) == jsonEncode(match));
    if (index < 0) { upcoming.add(row); } else { upcoming[index] = row; }
    validate();
  }
}
Map<String,dynamic> makePatch({String name = '', String start = '', String end = '', String itemName = '', String itemId = '', String sourceUrl = ''}) {
  final patch = <String,dynamic>{};
  final set = <String,dynamic>{};
  if (name.trim().isNotEmpty) set['names'] = {'zh-CN':name.trim()};
  if (start.trim().isNotEmpty) validateTime(start.trim());
  if (end.trim().isNotEmpty) validateTime(end.trim());
  if (start.trim().isNotEmpty || end.trim().isNotEmpty) {
    set['regions'] = [{'server':'cn_official', if (start.trim().isNotEmpty) 'startAt':start.trim(), if (end.trim().isNotEmpty) 'endAt':end.trim()}];
  }
  if (set.isNotEmpty) patch['set'] = set;
  if (itemName.trim().isNotEmpty) {
    final id = itemId.trim();
    if (id.isNotEmpty && !RegExp(r'^[1-9][0-9]*$').hasMatch(id)) throw const FormatException('Item ID 不合法');
    patch['itemIds'] = {itemName.trim(): id.isEmpty ? null : id};
  } else if (itemId.trim().isNotEmpty) { throw const FormatException('必须填写物品名称'); }
  if (sourceUrl.trim().isNotEmpty) {
    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) throw const FormatException('来源必须使用 HTTPS');
    patch['addSources'] = [{'provider':'external','url':sourceUrl.trim()}];
  }
  if (patch.isEmpty) throw const FormatException('至少填写一项修改内容');
  return patch;
}
class Repository {
  final HttpClient client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  Future<String> fetch(String url) async {
    final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 15));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final bytes = await res.fold<List<int>>(<int>[], (all, next) => all..addAll(next));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    return utf8.decode(bytes);
  }
  Future<Catalog> catalog(Game game) async => Catalog.parse(game, await fetch('$dataRoot/public/v1/${game.key}.json'));
  Future<ManualDocument> manual(Game game, String version) async {
    try {
      return ManualDocument.parse(game, version, await fetch('$dataRoot/manual/${game.key}_$version.json'));
    } on HttpException catch (e) {
      if (e.message == 'HTTP 404') return ManualDocument(game, version);
      rethrow;
    }
  }
  void dispose() => client.close();
}
