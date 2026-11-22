import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppDatabase, Repository, String)> openCard(WidgetTester tester) async {
    final db = await pumpNudge(tester);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final list = await repo.createList(board, 'Todo');
    final card = await repo.createCard(list, 'Bayar listrik');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar listrik'));
    await tester.pumpAndSettle();
    return (db, repo, card);
  }

  Future<void> addLabel(WidgetTester tester, String name, {int color = 1}) async {
    await tester.ensureVisible(find.byKey(const Key('add-label')));
    await tester.tap(find.byKey(const Key('add-label')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('label-name-field')), name);
    await tester.tap(find.byKey(Key('label-color-$color')));
    await tester.tap(find.byKey(const Key('label-save')));
    await tester.pumpAndSettle();
  }

  Future<List<String>> attachedNames(AppDatabase db, String cardId) async {
    final links = (await db.select(db.cardLabels).get())
        .where((l) => l.cardId == cardId && l.deletedAt == null);
    final labels = await db.select(db.labels).get();
    return [
      for (final l in links) labels.firstWhere((x) => x.id == l.labelId).name,
    ]..sort();
  }

  testWidgets('create a label from a card: it is attached and shows on the tile',
      (tester) async {
    final (db, _, cardId) = await openCard(tester);
    await addLabel(tester, 'Penting', color: 0);

    final label = (await db.select(db.labels).get()).single;
    expect(label.name, 'Penting');
    expect(await attachedNames(db, cardId), ['Penting']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-label-Penting')), findsOneWidget);
  });

  testWidgets('toggle a label off and on again reuses the same link',
      (tester) async {
    final (db, _, cardId) = await openCard(tester);
    await addLabel(tester, 'Rumah tangga');
    await tester.tap(find.byKey(const Key('label-Rumah tangga')));
    await tester.pumpAndSettle();
    expect(await attachedNames(db, cardId), isEmpty);

    await tester.tap(find.byKey(const Key('label-Rumah tangga')));
    await tester.pumpAndSettle();
    expect(await attachedNames(db, cardId), ['Rumah tangga']);
    expect((await db.select(db.cardLabels).get()).length, 1,
        reason: 'revived, not duplicated');
  });

  testWidgets('labels are shared by cards on the same board', (tester) async {
    final (db, repo, cardId) = await openCard(tester);
    await addLabel(tester, 'Urgent');
    final boards = await repo.watchBoards().first;
    final lists = await repo.watchLists(boards.single.id).first;
    final other = await repo.createCard(lists.single.id, 'Kartu lain');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kartu lain'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('label-Urgent')), findsOneWidget);
    await tester.tap(find.byKey(const Key('label-Urgent')));
    await tester.pumpAndSettle();
    expect(await attachedNames(db, other), ['Urgent']);
    expect(await attachedNames(db, cardId), ['Urgent']);
  });

  testWidgets('rename and delete a label (pencil)', (tester) async {
    final (db, _, cardId) = await openCard(tester);
    await addLabel(tester, 'Lama');

    await tester.tap(find.descendant(
        of: find.byKey(const Key('label-Lama')),
        matching: find.byKey(const Key('label-edit'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('label-name-field')), 'Baru');
    await tester.tap(find.byKey(const Key('label-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('label-Baru')), findsOneWidget);
    expect((await db.select(db.labels).get()).single.name, 'Baru');

    await tester.ensureVisible(find.byKey(const Key('label-Baru')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byKey(const Key('label-Baru')),
        matching: find.byKey(const Key('label-edit'))));
    await tester.pumpAndSettle();
    expect(find.text('Ubah label'), findsOneWidget, reason: 'edit dialog opened');
    await tester.tap(find.byKey(const Key('label-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('label-Baru')), findsNothing);
    final label = (await db.select(db.labels).get()).single;
    expect(label.deletedAt, isNotNull);
    expect(await attachedNames(db, cardId), isEmpty,
        reason: 'deleting a label detaches it everywhere');
  });

  testWidgets('empty label name is ignored', (tester) async {
    final (db, _, _) = await openCard(tester);
    await addLabel(tester, '   ');
    expect(await db.select(db.labels).get(), isEmpty);
  });
}
