import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Order of visible card titles in a list, by position.
  Future<List<String>> cardOrder(AppDatabase db, String listId) async {
    final cards = await db.select(db.cards).get();
    final mine = cards
        .where((c) => c.listId == listId && c.deletedAt == null)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return mine.map((c) => c.title).toList();
  }

  Future<List<String>> listOrder(AppDatabase db) async {
    final lists = await db.select(db.lists).get();
    lists.sort((a, b) => a.position.compareTo(b.position));
    return lists.map((l) => l.title).toList();
  }

  /// Long-press [from], drag to [to], release.
  Future<void> drag(WidgetTester tester, Finder from, Offset to) async {
    final start = tester.getCenter(from);
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600)); // long press
    await g.moveTo(start + const Offset(0, 8));
    await tester.pump(const Duration(milliseconds: 100));
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pumpAndSettle();
  }

  Future<(AppDatabase, String, String)> seedTwoLists(WidgetTester tester) async {
    // Wide surface so both columns are on screen at once.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = await pumpNudge(tester);
    final repo = Repository(db);
    final board = await repo.createBoard('Proyek');
    final todo = await repo.createList(board, 'Todo');
    final doing = await repo.createList(board, 'Doing');
    for (final t in ['A', 'B', 'C']) {
      await repo.createCard(todo, t);
    }
    await repo.createCard(doing, 'X');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proyek'));
    await tester.pumpAndSettle();
    return (db, todo, doing);
  }

  testWidgets('reorder cards within a list', (tester) async {
    final (db, todo, _) = await seedTwoLists(tester);
    expect(await cardOrder(db, todo), ['A', 'B', 'C']);

    // Drag C onto A -> C lands before A.
    await drag(tester, find.text('C'), tester.getCenter(find.text('A')));
    expect(await cardOrder(db, todo), ['C', 'A', 'B']);

    // Drag C (now first) onto the end drop zone -> last.
    await drag(tester, find.text('C'),
        tester.getCenter(find.byKey(const Key('drop-end-Todo'))));
    expect(await cardOrder(db, todo), ['A', 'B', 'C']);
  });

  testWidgets('move a card to another list', (tester) async {
    final (db, todo, doing) = await seedTwoLists(tester);

    // Drop B before X in Doing.
    await drag(tester, find.text('B'), tester.getCenter(find.text('X')));
    expect(await cardOrder(db, todo), ['A', 'C']);
    expect(await cardOrder(db, doing), ['B', 'X']);

    // Drop A at the end of Doing.
    await drag(tester, find.text('A'),
        tester.getCenter(find.byKey(const Key('drop-end-Doing'))));
    expect(await cardOrder(db, doing), ['B', 'X', 'A']);
    expect(await cardOrder(db, todo), ['C']);
  });

  testWidgets('drop a card into an empty list', (tester) async {
    final (db, todo, doing) = await seedTwoLists(tester);
    final repo = Repository(db);
    // Empty the Doing list.
    final x = (await db.select(db.cards).get()).firstWhere((c) => c.title == 'X');
    await repo.deleteCard(x.id);
    await tester.pumpAndSettle();

    await drag(tester, find.text('A'),
        tester.getCenter(find.byKey(const Key('drop-end-Doing'))));
    expect(await cardOrder(db, doing), ['A']);
    expect(await cardOrder(db, todo), ['B', 'C']);
  });

  testWidgets('reorder lists by dragging the header', (tester) async {
    final (db, _, _) = await seedTwoLists(tester);
    expect(await listOrder(db), ['Todo', 'Doing']);

    await drag(tester, find.byKey(const Key('list-handle-Doing')),
        tester.getCenter(find.byKey(const Key('list-handle-Todo'))));
    expect(await listOrder(db), ['Doing', 'Todo']);
  });

  testWidgets('"Pindahkan ke…" menu moves a card without dragging',
      (tester) async {
    final db = await pumpNudge(tester);
    final repo = Repository(db);
    final board = await repo.createBoard('Rumah');
    final a = await repo.createList(board, 'Todo');
    final b = await repo.createList(board, 'Selesai');
    await repo.createCard(a, 'Cuci mobil');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuci mobil'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pindahkan ke…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('move-to-Selesai')));
    await tester.pumpAndSettle();

    expect(await cardOrder(db, a), isEmpty);
    expect(await cardOrder(db, b), ['Cuci mobil']);
  });
}
