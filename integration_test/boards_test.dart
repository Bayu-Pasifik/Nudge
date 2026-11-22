import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> createBoard(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('add-board')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('board-title-field')), name);
    await tester.tap(find.byKey(const Key('save-board')));
    await tester.pumpAndSettle();
  }

  testWidgets('create, rename, archive and delete a board', (tester) async {
    await pumpNudge(tester);

    await createBoard(tester, 'Belanja');
    expect(find.text('Belanja'), findsOneWidget);
    expect(find.text('Belum ada board. Buat yang pertama.'), findsNothing);

    await createBoard(tester, 'Kerja');
    expect(find.text('Kerja'), findsOneWidget);

    // Rename
    await tester.tap(find.byKey(const Key('board-menu-Belanja')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('board-title-field')), 'Belanja Bulanan');
    await tester.tap(find.byKey(const Key('save-board')));
    await tester.pumpAndSettle();
    expect(find.text('Belanja Bulanan'), findsOneWidget);
    expect(find.text('Belanja'), findsNothing);

    // Archive
    await tester.tap(find.byKey(const Key('board-menu-Kerja')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan'));
    await tester.pumpAndSettle();
    expect(find.text('Kerja'), findsNothing);

    // Delete (with confirmation)
    await tester.tap(find.byKey(const Key('board-menu-Belanja Bulanan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-dialog')));
    await tester.pumpAndSettle();
    expect(find.text('Belanja Bulanan'), findsNothing);
    expect(find.text('Belum ada board. Buat yang pertama.'), findsOneWidget);
  });

  testWidgets('empty title is not saved', (tester) async {
    await pumpNudge(tester);
    await createBoard(tester, '   ');
    expect(find.text('Belum ada board. Buat yang pertama.'), findsOneWidget);
  });

  testWidgets('tapping a board opens it', (tester) async {
    await pumpNudge(tester);
    await createBoard(tester, 'Rumah');
    await tester.tap(find.text('Rumah'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('Rumah'), findsOneWidget);
  });
}
