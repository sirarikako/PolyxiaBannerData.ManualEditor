import 'dart:convert';
import 'dart:io';

enum Game {
  genshin('genshin', '原神', 'gi-', 'genshin-v1-overrides-v2'),
  starrail('starrail', '星铁', 'hsr-', 'starrail-v1-overrides-v1');

  const Game(this.key, this.label, this.prefix, this.format);
  final String key, label, prefix, format;
}

const dataRoot =
    'https://raw.githubusercontent.com/sirarikako/PolyxiaBannerData/main';

Map<String, dynamic> asObject(Object? x) {
  if (x is! Map<String, dynamic>) throw const FormatException('不是 JSON 对象');
  return x;
}

String requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field不能为空');
  }
  return value.trim();
}

void validateTime(String value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\+08:00$',
  ).firstMatch(value);
  if (match == null) {
    throw const FormatException('时间格式应为 YYYY-MM-DDTHH:mm:ss+08:00');
  }
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      parts[0] < 1 ||
      parts[3] > 23 ||
      parts[4] > 59 ||
      parts[5] > 59) {
    throw const FormatException('时间不是真实日期或时刻');
  }
}

class GachaBanner {
  GachaBanner(this.data);
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
  final List<GachaBanner> banners;
  factory Catalog.parse(Game game, String input) {
    final data = asObject(jsonDecode(input));
    if (data['game'] != game.key ||
        data['schemaVersion'] != 1 ||
        data['banners'] is! List) {
      throw const FormatException('公开数据版本或游戏不正确');
    }
    final seen = <String>{};
    final list = (data['banners'] as List)
        .map((x) => GachaBanner(asObject(x)))
        .toList();
    for (final b in list) {
      if (!b.id.startsWith(game.prefix) || !seen.add(b.id)) {
        throw const FormatException('卡池 ID 缺失或重复');
      }
    }
    return Catalog(list);
  }
  List<String> get versions {
    final values = banners
        .map((b) => b.version)
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    values.sort((a, b) => b.compareTo(a));
    return values;
  }

  List<GachaBanner> forVersion(String version) =>
      banners.where((b) => b.version == version && b.phase != null).toList();
}

class ManualDocument {
  ManualDocument(
    this.game,
    this.version, {
    List<Map<String, dynamic>>? upcoming,
    List<Map<String, dynamic>>? existing,
  }) : upcoming = upcoming ?? [],
       existing = existing ?? [];

  final Game game;
  final String version;
  final List<Map<String, dynamic>> upcoming;
  final List<Map<String, dynamic>> existing;

  factory ManualDocument.parse(Game game, String version, String input) {
    final obj = asObject(jsonDecode(input));
    if (obj.length != 6 ||
        obj['format'] != game.format ||
        obj['game'] != game.key ||
        obj['locale'] != 'zh-CN' ||
        obj['version'] != version) {
      throw const FormatException('人工文件格式、游戏或版本不匹配');
    }
    List<Map<String, dynamic>> rows(String key) {
      if (obj[key] is! List) throw FormatException('$key 必须为数组');
      return (obj[key] as List).map((row) => asObject(row)).toList();
    }

    final doc = ManualDocument(
      game,
      version,
      upcoming: rows('upcoming'),
      existing: rows('existing'),
    );
    doc.validate();
    return doc;
  }

  String get filename => '${game.key}_$version.json';
  String get formatted =>
      '${const JsonEncoder.withIndent('  ').convert({'format': game.format, 'game': game.key, 'locale': 'zh-CN', 'version': version, 'upcoming': upcoming, 'existing': existing})}\n';

  void validate() {
    requiredText(version, '版本');
    final ids = <String>{};
    for (final row in existing) {
      final id = requiredText(row['id'], '内部 ID');
      _checkId(id);
      if (row.containsKey('match')) {
        throw const FormatException('existing 不能包含 match');
      }
      _checkPatch(row, {'id'});
      if (_pending(row) && !ids.add(id)) {
        throw const FormatException('重复的待处理 existing');
      }
    }
    final matches = <String>{};
    for (final row in upcoming) {
      if (row.containsKey('id')) {
        throw const FormatException('upcoming 不能指定内部 ID');
      }
      final match = asObject(row['match']);
      _checkMatch(match);
      _checkPatch(row, {'match'});
      if (_pending(row) && !matches.add(_matchKey(match))) {
        throw const FormatException('重复的待处理 upcoming');
      }
    }
  }

  bool _pending(Map<String, dynamic> row) =>
      (row['status'] ?? 'pending') == 'pending';

  void _checkId(String id) {
    final prefix = game == Game.genshin ? 'gi-' : 'hsr-';
    final suffix = id.startsWith(prefix) ? id.substring(prefix.length) : '';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(suffix)) {
      throw const FormatException('内部 ID 格式无效');
    }
  }

  String _matchKey(Map<String, dynamic> match) {
    final keys = game == Game.genshin
        ? ['version', 'phase', 'poolType', 'variant', 'bannerName', 'postId']
        : ['version', 'phase', 'poolType', 'bannerName', 'fiveStarName'];
    return jsonEncode([
      for (final key in keys)
        key == 'version' ? (match[key] ?? version) : match[key],
    ]);
  }

  void _checkMatch(Map<String, dynamic> match) {
    final allowed = game == Game.genshin
        ? {'version', 'phase', 'poolType', 'variant', 'bannerName', 'postId'}
        : {'version', 'phase', 'poolType', 'bannerName', 'fiveStarName'};
    if (match.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('match 包含无效字段');
    }
    final p = match['phase'];
    if (p is! int || p < 1 || p > 9) throw const FormatException('期数必须为 1～9');
    final types = game == Game.genshin
        ? ['character_event', 'character_event_2', 'weapon_event', 'chronicled']
        : [
            'character_event',
            'light_cone_event',
            'collab_character',
            'collab_light_cone',
          ];
    if (!types.contains(match['poolType'])) {
      throw const FormatException('不支持的池类型');
    }
    if (match.containsKey('version') &&
        requiredText(match['version'], '匹配版本') != version) {
      throw const FormatException('匹配版本与文件版本不符');
    }
    if (game == Game.starrail || match.containsKey('bannerName')) {
      requiredText(match['bannerName'], '卡池名称');
    }
    if (match.containsKey('fiveStarName')) {
      requiredText(match['fiveStarName'], '五星名称');
    }
    if (match.containsKey('postId')) {
      final post = requiredText(match['postId'], '帖子 ID');
      if (!RegExp(r'^[0-9]+$').hasMatch(post)) {
        throw const FormatException('帖子 ID 格式错误');
      }
    }
    if (match.containsKey('variant') &&
        (match['poolType'] != 'chronicled' ||
            ![
              'chronicled',
              'special_recollection',
            ].contains(match['variant']))) {
      throw const FormatException('variant 仅限原神集录/溯光池');
    }
  }

  void _checkPatch(Map<String, dynamic> row, Set<String> identityKeys) {
    const allowed = {
      'status',
      'completedAt',
      'appliedId',
      'set',
      'itemIds',
      'addSources',
    };
    if (row.keys.any(
      (key) => !allowed.contains(key) && !identityKeys.contains(key),
    )) {
      throw const FormatException('补丁存在未知字段');
    }
    if (!['pending', 'completed'].contains(row['status'] ?? 'pending')) {
      throw const FormatException('status 不合法');
    }
    if (row.containsKey('completedAt')) {
      requiredText(row['completedAt'], 'completedAt');
    }
    if (row.containsKey('appliedId')) {
      _checkId(requiredText(row['appliedId'], 'appliedId'));
    }
    if (!row.containsKey('set') &&
        !row.containsKey('itemIds') &&
        !row.containsKey('addSources')) {
      throw const FormatException('缺少修改字段');
    }
    if (row.containsKey('set')) _checkSet(asObject(row['set']));
    if (row.containsKey('itemIds')) {
      for (final entry in asObject(row['itemIds']).entries) {
        requiredText(entry.key, '物品名');
        if (entry.value != null &&
            (entry.value is! String ||
                !RegExp(r'^[1-9][0-9]*$').hasMatch(entry.value as String))) {
          throw const FormatException('物品 ID 必须为数字字符串或 null');
        }
      }
    }
    if (row.containsKey('addSources')) {
      if (row['addSources'] is! List) {
        throw const FormatException('addSources 必须为数组');
      }
      for (final source in row['addSources'] as List) {
        _checkSource(asObject(source));
      }
    }
  }

  void _checkSet(Map<String, dynamic> set) {
    final allowed = game == Game.genshin
        ? {
            'names',
            'featured',
            'regions',
            'gachaTypes',
            'sources',
            'images',
            'fatePointLimit',
          }
        : {
            'names',
            'featured',
            'regions',
            'gachaTypes',
            'gachaIds',
            'sources',
            'images',
          };
    if (set.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('set 有不支持的字段');
    }
    if (set.containsKey('names')) _checkNames(asObject(set['names']));
    if (set.containsKey('images')) {
      final images = asObject(set['images']);
      _checkLocales(images);
      for (final value in images.values) {
        _checkUrl(value);
      }
    }
    if (set.containsKey('gachaTypes')) {
      final gacha = asObject(set['gachaTypes']);
      if (gacha.keys.any((key) => !{'raw', 'uigf'}.contains(key))) {
        throw const FormatException('gachaTypes 含未知键');
      }
      if (gacha.containsKey('raw') && gacha['raw'] != null) {
        _checkStrings(gacha['raw'], 'raw');
      }
      if (gacha.containsKey('uigf')) _checkStrings(gacha['uigf'], 'uigf');
    }
    if (set.containsKey('gachaIds')) {
      _checkStrings(set['gachaIds'], 'gachaIds', digits: true);
    }
    if (set.containsKey('fatePointLimit') &&
        ![null, 0, 1, 2].contains(set['fatePointLimit'])) {
      throw const FormatException('fatePointLimit 无效');
    }
    if (set.containsKey('featured')) {
      final featured = asObject(set['featured']);
      if (featured.keys.any((key) => !{'fiveStar', 'fourStar'}.contains(key))) {
        throw const FormatException('featured 存在未知字段');
      }
      for (final list in featured.values) {
        if (list == null) continue;
        if (list is! List) throw const FormatException('UP 列表不是数组');
        for (final entry in list) {
          final item = asObject(entry);
          if (item.keys.any(
                (key) => !{'itemId', 'names', 'type'}.contains(key),
              ) ||
              !item.containsKey('itemId') ||
              !['character', 'weapon', 'light_cone'].contains(item['type'])) {
            throw const FormatException('UP 物品格式不合法');
          }
          if (item['itemId'] != null &&
              (item['itemId'] is! String ||
                  !RegExp(r'^[0-9]+$').hasMatch(item['itemId'] as String))) {
            throw const FormatException('UP 的 ItemID 格式错误');
          }
          _checkNames(asObject(item['names']));
        }
      }
    }
    if (set.containsKey('regions')) {
      final regions = set['regions'];
      if (regions is! List || regions.length > 6) {
        throw const FormatException('regions 不是有效数组');
      }
      final servers = <String>{};
      const allowedServers = {
        'cn_official',
        'cn_channel',
        'asia',
        'europe',
        'america',
        'tw_hk_mo',
      };
      for (final entry in regions) {
        final region = asObject(entry);
        if (region.keys.any(
              (key) => !{'server', 'startAt', 'endAt'}.contains(key),
            ) ||
            !allowedServers.contains(region['server']) ||
            !servers.add(region['server'] as String)) {
          throw const FormatException('服务器无效、重复或字段异常');
        }
        if (region.containsKey('startAt')) {
          validateTime(requiredText(region['startAt'], '开始时间'));
        }
        if (region.containsKey('endAt')) {
          if (region['endAt'] == null) {
            if (game == Game.genshin) {
              throw const FormatException('原神结束时间不能为 null');
            }
          } else {
            validateTime(requiredText(region['endAt'], '结束时间'));
          }
        }
        if (region['startAt'] != null &&
            region['endAt'] != null &&
            DateTime.parse(region['startAt'] as String)
                    .compareTo(DateTime.parse(region['endAt'] as String)) >=
                0) {
          throw const FormatException('结束时间必须晚于开始时间');
        }
      }
    }
    if (set.containsKey('sources')) {
      final sources = set['sources'];
      if (sources is! List || sources.isEmpty) {
        throw const FormatException('sources 不能为空');
      }
      for (final source in sources) {
        _checkSource(asObject(source));
      }
    }
  }

  void _checkLocales(Map<String, dynamic> values) {
    if (values.keys.any(
      (key) => !RegExp(r'^[a-z]{2,3}(?:-[A-Z]{2})?$').hasMatch(key),
    )) {
      throw const FormatException('语言代码格式错误');
    }
  }

  void _checkNames(Map<String, dynamic> names) {
    if (names.isEmpty) throw const FormatException('名称不能为空');
    _checkLocales(names);
    for (final text in names.values) {
      requiredText(text, '本地化名称');
    }
  }

  void _checkStrings(Object? value, String label, {bool digits = false}) {
    if (value is! List || value.isEmpty) {
      throw FormatException('$label 必须为非空数组');
    }
    final seen = <String>{};
    for (final entry in value) {
      final text = requiredText(entry, label);
      if (!seen.add(text) || (digits && !RegExp(r'^[0-9]+$').hasMatch(text))) {
        throw FormatException('$label 包含重复或非法值');
      }
    }
  }

  void _checkSource(Map<String, dynamic> source) {
    if (source.keys.any(
      (key) => !{'provider', 'externalId', 'url'}.contains(key),
    )) {
      throw const FormatException('来源包含额外字段');
    }
    requiredText(source['provider'], 'provider');
    if (source.containsKey('externalId')) {
      requiredText(source['externalId'], 'externalId');
    }
    if (source.containsKey('url')) _checkUrl(source['url']);
  }

  void _checkUrl(Object? value) {
    final input = requiredText(value, 'HTTPS URL');
    final uri = Uri.tryParse(input);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        input.contains(RegExp(r'\s'))) {
      throw const FormatException('来源或图片 URL 必须是合法 HTTPS');
    }
  }

  Map<String, dynamic> _mergeMap(
    Map<String, dynamic> old,
    Map<String, dynamic> patch,
  ) {
    final result = Map<String, dynamic>.from(old);
    for (final entry in patch.entries) {
      final previous = result[entry.key];
      if (entry.key == 'regions' && previous is List && entry.value is List) {
        final regions = [
          for (final value in previous)
            Map<String, dynamic>.from(asObject(value)),
        ];
        for (final value in entry.value as List) {
          final region = asObject(value);
          final index = regions.indexWhere(
            (r) => r['server'] == region['server'],
          );
          if (index < 0) {
            regions.add(Map<String, dynamic>.from(region));
          } else {
            regions[index] = {...regions[index], ...region};
          }
        }
        result[entry.key] = regions;
      } else if (previous is Map<String, dynamic> &&
          entry.value is Map<String, dynamic>) {
        result[entry.key] = _mergeMap(
          previous,
          entry.value as Map<String, dynamic>,
        );
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<String, dynamic> _mergePatch(
    Map<String, dynamic> old,
    Map<String, dynamic> patch,
  ) {
    final result = Map<String, dynamic>.from(old);
    for (final entry in patch.entries) {
      if (entry.key == 'set' || entry.key == 'itemIds') {
        result[entry.key] = _mergeMap(
          result[entry.key] is Map<String, dynamic>
              ? result[entry.key] as Map<String, dynamic>
              : <String, dynamic>{},
          asObject(entry.value),
        );
      } else if (entry.key == 'addSources') {
        final sources = <dynamic>[
          if (result['addSources'] is List) ...result['addSources'] as List,
        ];
        for (final source in entry.value as List) {
          if (!sources.any(
            (value) => jsonEncode(value) == jsonEncode(source),
          )) {
            sources.add(source);
          }
        }
        result['addSources'] = sources;
      }
    }
    return result;
  }

  void _stage(
    bool isUpcoming,
    Map<String, dynamic> identity,
    Map<String, dynamic> patch,
  ) {
    final nextUpcoming = (jsonDecode(jsonEncode(upcoming)) as List)
        .map((e) => asObject(e))
        .toList();
    final nextExisting = (jsonDecode(jsonEncode(existing)) as List)
        .map((e) => asObject(e))
        .toList();
    final rows = isUpcoming ? nextUpcoming : nextExisting;
    final key = isUpcoming ? 'match' : 'id';
    final target = isUpcoming ? _matchKey(identity) : identity['id'];
    final index = rows.indexWhere(
      (row) =>
          _pending(row) &&
          (isUpcoming
              ? _matchKey(asObject(row['match'])) == target
              : row['id'] == target),
    );
    final prior = index < 0
        ? <String, dynamic>{
            key: isUpcoming ? identity : identity['id'],
            'status': 'pending',
          }
        : rows[index];
    final updated = _mergePatch(prior, patch);
    if (index < 0) {
      rows.add(updated);
    } else {
      rows[index] = updated;
    }
    ManualDocument(
      game,
      version,
      upcoming: nextUpcoming,
      existing: nextExisting,
    ).validate();
    upcoming
      ..clear()
      ..addAll(nextUpcoming);
    existing
      ..clear()
      ..addAll(nextExisting);
  }

  void addExisting(GachaBanner banner, Map<String, dynamic> patch) {
    if (banner.version != version) throw const FormatException('卡池版本不一致');
    _checkId(banner.id);
    _stage(false, {'id': banner.id}, patch);
  }

  void addUpcoming(Map<String, dynamic> match, Map<String, dynamic> patch) {
    _checkMatch(match);
    _stage(true, match, patch);
  }
}

Map<String, dynamic> makePatch({
  String name = '',
  String start = '',
  String end = '',
  String itemName = '',
  String itemId = '',
  String sourceUrl = '',
}) {
  final patch = <String, dynamic>{};
  final set = <String, dynamic>{};
  if (name.trim().isNotEmpty) set['names'] = {'zh-CN': name.trim()};
  if (start.trim().isNotEmpty) validateTime(start.trim());
  if (end.trim().isNotEmpty) validateTime(end.trim());
  if (start.trim().isNotEmpty &&
      end.trim().isNotEmpty &&
      DateTime.parse(start.trim()).compareTo(DateTime.parse(end.trim())) >= 0) {
    throw const FormatException('结束时间必须晚于开始时间');
  }
  if (start.trim().isNotEmpty || end.trim().isNotEmpty) {
    set['regions'] = [
      {
        'server': 'cn_official',
        if (start.trim().isNotEmpty) 'startAt': start.trim(),
        if (end.trim().isNotEmpty) 'endAt': end.trim(),
      },
    ];
  }
  if (set.isNotEmpty) patch['set'] = set;
  if (itemName.trim().isNotEmpty) {
    final id = itemId.trim();
    if (id.isNotEmpty && !RegExp(r'^[1-9][0-9]*$').hasMatch(id)) {
      throw const FormatException('ItemID 不合法');
    }
    patch['itemIds'] = {itemName.trim(): id.isEmpty ? null : id};
  } else if (itemId.trim().isNotEmpty) {
    throw const FormatException('请先填写物品名称');
  }
  if (sourceUrl.trim().isNotEmpty) {
    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        sourceUrl.trim().contains(RegExp(r'\s'))) {
      throw const FormatException('来源 URL 必须为合法 HTTPS');
    }
    patch['addSources'] = [
      {'provider': 'external', 'url': sourceUrl.trim()},
    ];
  }
  if (patch.isEmpty) throw const FormatException('至少填写一项修改内容');
  return patch;
}

class Repository {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);
  Future<String> fetch(String url) async {
    final req = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 15));
    final res = await req.close().timeout(const Duration(seconds: 15));
    final bytes = await res.fold<List<int>>(
      <int>[],
      (all, next) => all..addAll(next),
    );
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    }
    return utf8.decode(bytes);
  }

  Future<Catalog> catalog(Game game) async =>
      Catalog.parse(game, await fetch('$dataRoot/public/v1/${game.key}.json'));
  Future<ManualDocument> manual(Game game, String version) async {
    try {
      return ManualDocument.parse(
        game,
        version,
        await fetch('$dataRoot/manual/${game.key}_$version.json'),
      );
    } on HttpException catch (e) {
      if (e.message == 'HTTP 404') return ManualDocument(game, version);
      rethrow;
    }
  }

  void dispose() => client.close();
}
