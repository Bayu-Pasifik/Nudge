import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openNewBoard(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('add-board')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('board-title-field')), name);
    await tester.tap(find.byKey(const Key('save-board')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> addList(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('add-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('prompt-field')), name);
    await tester.tap(find.byKey(const Key('prompt-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('add list, quick-add cards, complete a card', (tester) async {
    final db = await pumpNudge(tester);
    await openNewBoard(tester, 'Rumah');

    expect(find.text('Tambah list pertama'), findsOneWidget);
    await addList(tester, 'Hari Ini');
    expect(find.text('Hari Ini'), findsOneWidget);
    expect(find.text('Tambah list'), findsOneWidget);

    // Quick add stays open for rapid entry.
    await tester.tap(find.byKey(const Key('add-card-Hari Ini')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick-add-field')), 'Cuci piring');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick-add-field')), 'Buang sampah');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Cuci piring'), findsOneWidget);
    expect(find.text('Buang sampah'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // list count badge

    // Complete the first card.
    await tester.tap(find.byKey(const Key('complete-Cuci piring')));
    await tester.pumpAndSettle();
    final cards = await db.select(db.cards).get();
    expect(cards.firstWhere((c) => c.title == 'Cuci piring').completedAt,
        isNotNull);
    expect(cards.firstWhere((c) => c.title == 'Buang sampah').completedAt,
        isNull);

    // Un-complete.
    await tester.tap(find.byKey(const Key('complete-Cuci piring')));
    await tester.pumpAndSettle();
    final again = await db.select(db.cards).get();
    expect(again.firstWhere((c) => c.title == 'Cuci piring').completedAt,
        isNull);
  });

  testWidgets('rename and archive a list', (tester) async {
    await pumpNudge(tester);
    await openNewBoard(tester, 'Kerja');
    await addList(tester, 'Todo');

    await tester.tap(find.byKey(const Key('list-menu-Todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('prompt-field')), 'Sedang jalan');
    await tester.tap(find.byKey(const Key('prompt-save')));
    await tester.pumpAndSettle();
    expect(find.text('Sedang jalan'), findsOneWidget);
    expect(find.text('Todo'), findsNothing);

    await tester.tap(find.byKey(const Key('list-menu-Sedang jalan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog')));
    await tester.pumpAndSettle();
    expect(find.text('Sedang jalan'), findsNothing);
    expect(find.text('Tambah list pertama'), findsOneWidget);
  });
}
