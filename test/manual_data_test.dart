import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyxia_banner_data_manual_editor/manual_data.dart';

void main() {
  test('catalog checks game and version', () {
    final text = jsonEncode({
      'game': 'genshin',
      'schemaVersion': 1,
      'banners': [
        {
          'id': 'gi-000001',
          'gameVersion': '7.1',
          'phase': 1,
          'poolType': 'character_event',
          'names': {'zh-CN': '测试'},
        },
      ],
    });
    expect(
      Catalog.parse(Game.genshin, text).forVersion('7.1').single.title,
      '测试',
    );
    expect(() => Catalog.parse(Game.starrail, text), throwsFormatException);
  });
  test('existing patches replace only matching id', () {
    final doc = ManualDocument(Game.genshin, '7.1');
    final b = GachaBanner({'id': 'gi-000001', 'gameVersion': '7.1'});
    doc.addExisting(b, makePatch(name: '甲'));
    doc.addExisting(b, makePatch(itemName: '乙', itemId: '123'));
    expect(doc.existing.length, 1);
    expect(doc.existing.single['set'], {
      'names': {'zh-CN': '甲'},
    });
    expect(doc.existing.single['itemIds'], {'乙': '123'});
    expect(
      () => doc.addExisting(
        GachaBanner({'id': 'gi-000002', 'gameVersion': '7.2'}),
        makePatch(name: '丙'),
      ),
      throwsFormatException,
    );
  });
  test('upcoming matches and rejects invalid phase', () {
    final doc = ManualDocument(Game.starrail, '4.0');
    doc.addUpcoming({
      'phase': 1,
      'poolType': 'light_cone_event',
      'bannerName': '测试',
    }, makePatch(name: '测试'));
    expect(doc.upcoming.length, 1);
    expect(
      () => doc.addUpcoming({
        'phase': 10,
        'poolType': 'light_cone_event',
        'bannerName': '错误',
      }, makePatch(name: '坏')),
      throwsFormatException,
    );
    expect(doc.upcoming.length, 1);
    expect(
      ManualDocument.parse(Game.starrail, '4.0', doc.formatted).upcoming.length,
      1,
    );
  });
  test('completed existing stays intact and new edits become pending', () {
    final doc = ManualDocument(
      Game.genshin,
      '7.1',
      existing: [
        {
          'id': 'gi-000001',
          'status': 'completed',
          'completedAt': '2026-01-01',
          'appliedId': 'gi-000001',
          'set': {
            'names': {'zh-CN': '旧名称'},
          },
        },
      ],
    );
    doc.addExisting(
      GachaBanner({'id': 'gi-000001', 'gameVersion': '7.1'}),
      makePatch(name: '新名称'),
    );
    expect(doc.existing.length, 2);
    expect(doc.existing.first['status'], 'completed');
    expect((doc.existing.first['set'] as Map)['names'], {'zh-CN': '旧名称'});
    expect(doc.existing.last['status'], 'pending');
  });

  test('failed staged update leaves draft untouched', () {
    final doc = ManualDocument(Game.genshin, '7.1');
    final b = GachaBanner({'id': 'gi-000001', 'gameVersion': '7.1'});
    doc.addExisting(b, makePatch(name: '原值'));
    final before = doc.formatted;
    expect(
      () => doc.addExisting(b, {
        'set': {'unknown': '坏值'},
      }),
      throwsFormatException,
    );
    expect(doc.formatted, before);
  });

  test('upcoming equivalence ignores map order and explicit file version', () {
    final doc = ManualDocument(Game.starrail, '4.0');
    doc.addUpcoming({
      'phase': 1,
      'poolType': 'light_cone_event',
      'bannerName': '测试',
    }, makePatch(itemName: '测试光锥', itemId: '1001'));
    doc.addUpcoming({
      'bannerName': '测试',
      'poolType': 'light_cone_event',
      'version': '4.0',
      'phase': 1,
    }, makePatch(name: '新名字'));
    expect(doc.upcoming.length, 1);
    expect(doc.upcoming.single['itemIds'], {'测试光锥': '1001'});
    expect((doc.upcoming.single['set'] as Map)['names'], {'zh-CN': '新名字'});
  });

  test('merge regions by server and reject invalid calendar date', () {
    final doc = ManualDocument(Game.genshin, '7.1');
    final b = GachaBanner({'id': 'gi-000001', 'gameVersion': '7.1'});
    doc.addExisting(b, makePatch(start: '2026-10-30T18:00:00+08:00'));
    doc.addExisting(b, makePatch(end: '2026-11-20T15:00:00+08:00'));
    final regions = ((doc.existing.single['set'] as Map)['regions'] as List);
    expect(regions.length, 1);
    expect(regions.single['startAt'], '2026-10-30T18:00:00+08:00');
    expect(regions.single['endAt'], '2026-11-20T15:00:00+08:00');
    expect(
      () => makePatch(start: '2026-02-30T18:00:00+08:00'),
      throwsFormatException,
    );
  });

  test('patch prevents illegal values', () {
    expect(() => makePatch(), throwsFormatException);
    expect(() => makePatch(start: 'wrong'), throwsFormatException);
    expect(() => makePatch(itemName: '甲', itemId: '-1'), throwsFormatException);
    expect(
      () => makePatch(sourceUrl: 'http://example.com'),
      throwsFormatException,
    );
    expect(makePatch(itemName: '甲')['itemIds'], {'甲': null});
  });
}
