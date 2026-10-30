import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyxia_banner_data_manual_editor/manual_data.dart';

void main() {
  test('catalog checks game and version', () {
    final text = jsonEncode({'game':'genshin','schemaVersion':1,'banners':[
      {'id':'gi-000001','gameVersion':'7.1','phase':1,'poolType':'character_event','names':{'zh-CN':'测试'}},
    ]});
    expect(Catalog.parse(Game.genshin,text).forVersion('7.1').single.title,'测试');
    expect(() => Catalog.parse(Game.starrail,text),throwsFormatException);
  });
  test('existing patches replace only matching id', () {
    final doc=ManualDocument(Game.genshin,'7.1');
    final b=Banner({'id':'gi-000001','gameVersion':'7.1'});
    doc.addExisting(b,makePatch(name:'甲'));
    doc.addExisting(b,makePatch(itemName:'乙',itemId:'123'));
    expect(doc.existing.length,1);
    expect(doc.existing.single['itemIds'],{'乙':'123'});
    expect(() => doc.addExisting(Banner({'id':'gi-000002','gameVersion':'7.2'}),makePatch(name:'丙')),throwsFormatException);
  });
  test('upcoming matches and rejects invalid phase', () {
    final doc=ManualDocument(Game.starrail,'4.0');
    doc.addUpcoming({'phase':1,'poolType':'light_cone_event','bannerName':'测试'},makePatch(name:'测试'));
    expect(doc.upcoming.length,1);
    expect(() => doc.addUpcoming({'phase':10,'poolType':'light_cone_event','bannerName':'错误'},makePatch(name:'坏')),throwsFormatException);
    expect(ManualDocument.parse(Game.starrail,'4.0',doc.formatted).upcoming.length,1);
  });
  test('patch prevents illegal values', () {
    expect(() => makePatch(),throwsFormatException);
    expect(() => makePatch(start:'wrong'),throwsFormatException);
    expect(() => makePatch(itemName:'甲',itemId:'-1'),throwsFormatException);
    expect(() => makePatch(sourceUrl:'http://example.com'),throwsFormatException);
    expect(makePatch(itemName:'甲')['itemIds'],{'甲':null});
  });
}
