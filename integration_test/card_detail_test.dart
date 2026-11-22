import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Seeds board > list > card, then opens the card detail.
  Future<(AppDatabase, Repository, String)> openCard(
    WidgetTester tester, {
    String cardTitle = 'Bayar listrik',
  }) async {
    final db = await pumpNudge(tester);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    final card = await repo.createCard(list, cardTitle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(cardTitle));
    await tester.pumpAndSettle();
    return (db, repo, card);
  }

  testWidgets('edit title and description, persisted after leaving',
      (tester) async {
    final (db, _, cardId) = await openCard(tester);
    expect(find.byKey(const Key('detail-title')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('detail-title')), 'Bayar listrik & air');
    await tester.enterText(
        find.byKey(const Key('detail-desc')), 'Token PLN 100rb');
    // Leave the screen: edits must be saved without an explicit save button.
    await tester.pageBack();
    await tester.pumpAndSettle();

    final card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.title, 'Bayar listrik & air');
    expect(card.description, 'Token PLN 100rb');
    expect(find.text('Bayar listrik & air'), findsOneWidget);
  });

  testWidgets('checklist: add, edit, check, delete', (tester) async {
    final (db, _, cardId) = await openCard(tester);

    for (final text in ['Cek meteran', 'Transfer']) {
      await tester.enterText(
          find.byKey(const Key('checklist-add-field')), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('check-text-Cek meteran')), findsOneWidget);
    expect(find.byKey(const Key('check-text-Transfer')), findsOneWidget);
    expect(find.text('0/2'), findsOneWidget);

    // Check first item.
    await tester.tap(find.byKey(const Key('check-Cek meteran')));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);

    // Edit text inline.
    await tester.enterText(
        find.byKey(const Key('check-text-Transfer')), 'Transfer ke PLN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    var items = await db.select(db.checklistItems).get();
    expect(items.map((i) => i.text_), contains('Transfer ke PLN'));

    // Delete an item.
    await tester.tap(find.byKey(const Key('check-delete-Cek meteran')));
    await tester.pumpAndSettle();
    items = await db.select(db.checklistItems).get();
    final alive = items.where((i) => i.deletedAt == null && i.cardId == cardId);
    expect(alive.length, 1);
  });

  testWidgets('auto-complete card when all checklist items are done',
      (tester) async {
    final (db, repo, cardId) = await openCard(tester);
    await repo.addChecklistItem(cardId, 'A');
    await repo.addChecklistItem(cardId, 'B');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('auto-complete-switch')));
    await tester.tap(find.byKey(const Key('auto-complete-switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('check-A')));
    await tester.pumpAndSettle();
    var card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.completedAt, isNull, reason: 'not all items done yet');

    await tester.tap(find.byKey(const Key('check-B')));
    await tester.pumpAndSettle();
    card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.completedAt, isNotNull);
  });

  testWidgets('set and clear due date', (tester) async {
    final (db, _, cardId) = await openCard(tester);

    await tester.tap(find.byKey(const Key('pick-due')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date dialog (today preselected)
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time dialog
    await tester.pumpAndSettle();

    var card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.dueAt, isNotNull);
    expect(find.textContaining('Hari ini'), findsWidgets);

    await tester.tap(find.byKey(const Key('clear-due')));
    await tester.pumpAndSettle();
    card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.dueAt, isNull);
    expect(find.text('Atur tanggal'), findsOneWidget);
  });

  testWidgets('complete from detail, archive and delete', (tester) async {
    final (db, _, cardId) = await openCard(tester);

    await tester.tap(find.byKey(const Key('detail-complete')));
    await tester.pumpAndSettle();
    var card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.completedAt, isNotNull);

    await tester.tap(find.byKey(const Key('card-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog')));
    await tester.pumpAndSettle();

    card = await (db.select(db.cards)..where((c) => c.id.equals(cardId)))
        .getSingle();
    expect(card.deletedAt, isNotNull);
    // Back on the board, the card is gone.
    expect(find.text('Bayar listrik'), findsNothing);
  });
}
