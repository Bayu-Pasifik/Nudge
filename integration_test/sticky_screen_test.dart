import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/app.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/desktop/sticky_mode.dart';

import 'test_helpers.dart';

/// Records what sticky mode asked the OS window to do.
class RecordingWindow implements WindowController {
  final calls = <String>[];
  @override
  Future<void> enterSticky() async => calls.add('enter');
  @override
  Future<void> exitSticky() async => calls.add('exit');
  @override
  Future<void> show() async => calls.add('show');
  @override
  Future<void> raiseTemporarily() async => calls.add('raise');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(NudgeApp)));

  testWidgets('sticky mode shows pinned notes, ticks items and finishes cards',
      (tester) async {
    final db = await pumpNudge(tester, startOnBoards: false);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    final a = await repo.createCard(list, 'Belanja');
    await repo.addChecklistItem(a, 'Susu');
    await repo.updateCard(a, pinned: true, stickyColor: 'mint');
    final b = await repo.createCard(list, 'Telepon');
    await repo.updateCard(b, pinned: true);
    await repo.createCard(list, 'Tidak ter-pin');
    await tester.pumpAndSettle();

    await container(tester).read(stickyModeProvider.notifier).set(true);
    await tester.pumpAndSettle();

    expect(find.text('Sticky'), findsOneWidget);
    expect(find.text('Belanja'), findsOneWidget);
    expect(find.text('Telepon'), findsOneWidget);
    expect(find.text('Tidak ter-pin'), findsNothing);
    expect(find.text('Susu'), findsOneWidget);

    // Tick a checklist item right from the sticky note.
    await tester.tap(find.byKey(const Key('sticky-check-Susu')));
    await tester.pumpAndSettle();
    final items = await db.select(db.checklistItems).get();
    expect(items.single.done, isTrue);

    // Finish a card: its note disappears.
    await tester.tap(find.byKey(const Key('sticky-done-Telepon')));
    await tester.pumpAndSettle();
    expect(find.text('Telepon'), findsNothing);
    expect(find.text('Belanja'), findsOneWidget);

    // Back to the full window.
    await tester.tap(find.byKey(const Key('sticky-exit')));
    await tester.pumpAndSettle();
    expect(find.text('Sticky'), findsNothing);
    expect(find.text('Hari ini'), findsWidgets);
  });

  testWidgets('sticky mode drives the OS window and empty state',
      (tester) async {
    final window = RecordingWindow();
    await pumpNudge(tester, startOnBoards: false, window: window);
    final c = container(tester);

    await c.read(stickyModeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(window.calls, ['enter']);
    expect(find.byKey(const Key('sticky-empty')), findsOneWidget);

    await c.read(stickyModeProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(window.calls, ['enter', 'exit']);
  });
}
