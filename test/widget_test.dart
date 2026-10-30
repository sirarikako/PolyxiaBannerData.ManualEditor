import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyxia_banner_data_manual_editor/main.dart';

void main() {
  testWidgets('Editor shell replaces demo counter', (tester) async {
    await tester.pumpWidget(const ManualEditorApp());
    expect(find.text('Polyxia Manual Editor'), findsOneWidget);
    expect(find.text('原神'), findsOneWidget);
    expect(find.text('星铁'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}
