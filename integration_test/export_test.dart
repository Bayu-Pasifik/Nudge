import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/export/export_json.dart';
import 'package:nudge/core/export/export_service.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export contains every live row and skips deleted ones',
      (tester) async {
    final db = await pumpNudge(tester, startOnBoards: false);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    final keep = await repo.createCard(list, 'Bayar listrik');
    final gone = await repo.createCard(list, 'Dihapus');
    await repo.addChecklistItem(keep, 'Cek meteran');
    await repo.addReminder(keep, DateTime(2026, 11, 22, 18), intervalMinutes: 5);
    final label = await repo.createLabel(board, 'Penting', 0xFFE5484D);
    await repo.setCardLabel(keep, label, true);
    await repo.deleteCard(gone);

    final json = jsonDecode(await buildExportJson(db)) as Map<String, dynamic>;
    expect(json['app'], 'Nudge');
    expect(json['format'], exportFormatVersion);
    final counts = json['counts'] as Map<String, dynamic>;
    expect(counts['boards'], 1);
    expect(counts['lists'], 1);
    expect(counts['cards'], 1, reason: 'tombstoned card is not exported');
    expect(counts['checklist_items'], 1);
    expect(counts['reminders'], 1);
    expect(counts['labels'], 1);
    expect(counts['card_labels'], 1);

    final cards = (json['data'] as Map)['cards'] as List;
    expect((cards.single as Map)['title'], 'Bayar listrik');
    expect((cards.single as Map).containsKey('user_id'), isFalse);
    final reminders = (json['data'] as Map)['reminders'] as List;
    expect((reminders.single as Map)['nag_interval_minutes'], 5);
  });

  testWidgets('empty database exports an empty but valid file', (tester) async {
    final db = await pumpNudge(tester, startOnBoards: false);
    final json = jsonDecode(await buildExportJson(db)) as Map<String, dynamic>;
    final counts = json['counts'] as Map<String, dynamic>;
    expect(counts.values.every((v) => v == 0), isTrue);
  });

  testWidgets('exportAll writes a readable file', (tester) async {
    final db = await pumpNudge(tester, startOnBoards: false);
    await Repository(db).createBoard('Cadangan');
    final dir = await Directory.systemTemp.createTemp('nudge_export');
    addTearDown(() => dir.delete(recursive: true));
    final r = await tester.runAsync(() => exportAll(db, directory: dir));
    final text = await File(r!.path).readAsString();
    expect(jsonDecode(text)['counts']['boards'], 1);
    expect(r.path, contains('nudge-export-'));
  });

  testWidgets('Settings: export button copies JSON to the clipboard',
      (tester) async {
    final db = await pumpNudge(tester, startOnBoards: false);
    await Repository(db).createBoard('Dari tombol');
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    // Settings is a lazy ListView: scroll until the tile is actually built.
    await tester.scrollUntilVisible(
      find.byKey(const Key('export-json')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('export-json')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export-done')), findsOneWidget);
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    expect(jsonDecode(clip!.text!)['counts']['boards'], 1);
  });
}
