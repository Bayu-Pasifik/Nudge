import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/repository.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('new reminders start from the defaults set in Pengaturan',
      (tester) async {
    final db = await pumpNudge(tester);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    await repo.createCard(list, 'Minum obat');
    await tester.pumpAndSettle();

    await openSettings(tester);
    await tester.tap(find.byKey(const Key('default-interval-30')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('default-max-5')));
    await tester.tap(find.byKey(const Key('default-max-5')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('default-escalate')));
    await tester.tap(find.byKey(const Key('default-escalate')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('default-quiet')));
    await tester.tap(find.byKey(const Key('default-quiet')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-boards')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minum obat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-reminder')));
    await tester.tap(find.byKey(const Key('add-reminder')));
    await tester.pumpAndSettle();

    // The sheet opens pre-selected with the defaults.
    final interval =
        tester.widget<ChoiceChip>(find.byKey(const Key('interval-30')));
    expect(interval.selected, isTrue);
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('max-5'))).selected,
      isTrue,
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('escalate-switch'))).value,
      isFalse,
    );
    expect(
      tester.widget<SwitchListTile>(find.byKey(const Key('quiet-switch'))).value,
      isFalse,
    );

    await tester.ensureVisible(find.byKey(const Key('save-reminder')));
    await tester.tap(find.byKey(const Key('save-reminder')));
    await tester.pumpAndSettle();
    final r = (await db.select(db.reminders).get()).single;
    expect(r.nagIntervalMinutes, 30);
    expect(r.nagMaxCount, 5);
    expect(r.escalation, isNull);
    expect(r.quietStartMinute, isNull);
  });

  testWidgets('defaults survive a restart (stored in preferences)',
      (tester) async {
    await pumpNudge(
      tester,
      startOnBoards: false,
      prefsValues: {
        'nag_default_interval': 15,
        'nag_default_max': 20,
        'nag_default_escalate': false,
        'nag_default_quiet': true,
        'nag_default_quiet_start': 23 * 60,
        'nag_default_quiet_end': 6 * 60,
      },
    );
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('default-interval-15'))).selected,
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const Key('default-max-20')));
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('default-max-20'))).selected,
      isTrue,
    );
    expect(find.textContaining('23:00–06:00'), findsOneWidget);
  });
}
