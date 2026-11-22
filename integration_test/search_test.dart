import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/repository.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(const Key('search-field')), q);
    await tester.pumpAndSettle();
  }

  Future<Repository> seed(WidgetTester tester) async {
    final db = await pumpNudge(tester, startOnBoards: false);
    final repo = Repository(db);
    final rumah = await repo.createBoard('Rumah');
    final todo = await repo.createList(rumah, 'Todo');
    final belanja = await repo.createBoard('Belanja');
    final mingguan = await repo.createList(belanja, 'Mingguan');

    final listrik = await repo.createCard(todo, 'Bayar listrik');
    await repo.updateCard(listrik, description: 'Token PLN bulanan');
    final pajak = await repo.createCard(todo, 'Bayar pajak');
    final now = DateTime.now();
    await repo.updateCard(pajak,
        dueAt: Value(DateTime(now.year, now.month, now.day - 3)), pinned: true);
    final susu = await repo.createCard(mingguan, 'Beli susu');
    final selesai = await repo.createCard(mingguan, 'Beli roti');
    await repo.setCardCompleted(selesai, true);

    final penting = await repo.createLabel(rumah, 'Penting', 0xFFE5484D);
    await repo.setCardLabel(pajak, penting, true);
    await repo.setCardLabel(listrik, penting, true);
    expect(susu, isNotEmpty);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-search')));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('lists open cards, hides finished ones by default',
      (tester) async {
    await seed(tester);
    expect(find.text('Bayar listrik'), findsOneWidget);
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Beli susu'), findsOneWidget);
    expect(find.text('Beli roti'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-done')));
    await tester.pumpAndSettle();
    expect(find.text('Beli roti'), findsOneWidget);
  });

  testWidgets('text search across title, description, board and list',
      (tester) async {
    await seed(tester);
    await search(tester, 'bayar');
    expect(find.text('Bayar listrik'), findsOneWidget);
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Beli susu'), findsNothing);

    await search(tester, 'pln');
    expect(find.text('Bayar listrik'), findsOneWidget);
    expect(find.text('Bayar pajak'), findsNothing);

    await search(tester, 'mingguan');
    expect(find.text('Beli susu'), findsOneWidget);

    await search(tester, 'tidak ada yang cocok');
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(find.text('Tidak ada kartu yang cocok.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Beli susu'), findsOneWidget);
  });

  testWidgets('filters: pinned, overdue and label', (tester) async {
    await seed(tester);

    await tester.tap(find.byKey(const Key('filter-pinned')));
    await tester.pumpAndSettle();
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Bayar listrik'), findsNothing);
    await tester.tap(find.byKey(const Key('filter-pinned')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-overdue')));
    await tester.pumpAndSettle();
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Beli susu'), findsNothing);
    await tester.tap(find.byKey(const Key('filter-overdue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-label-Penting')));
    await tester.pumpAndSettle();
    expect(find.text('Bayar listrik'), findsOneWidget);
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Beli susu'), findsNothing);

    // Combine label + text.
    await search(tester, 'pajak');
    expect(find.text('Bayar pajak'), findsOneWidget);
    expect(find.text('Bayar listrik'), findsNothing);
  });

  testWidgets('tapping a result opens the card', (tester) async {
    await seed(tester);
    await tester.tap(find.text('Beli susu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-title')), findsOneWidget);
  });
}
