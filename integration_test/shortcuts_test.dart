import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+1/2/3 switch tabs', (tester) async {
    await pumpNudge(tester, startOnBoards: false);
    expect(find.text('Tidak ada yang mendesak hari ini.'), findsOneWidget);

    await ctrl(tester, LogicalKeyboardKey.digit2);
    expect(find.text('Belum ada board. Buat yang pertama.'), findsOneWidget);

    await ctrl(tester, LogicalKeyboardKey.digit3);
    expect(find.byKey(const Key('search-field')), findsOneWidget);

    await ctrl(tester, LogicalKeyboardKey.digit1);
    expect(find.text('Tidak ada yang mendesak hari ini.'), findsOneWidget);
  });

  testWidgets('Ctrl+K opens search with the cursor in the box', (tester) async {
    await pumpNudge(tester, startOnBoards: false);
    await ctrl(tester, LogicalKeyboardKey.keyK);

    expect(find.byKey(const Key('search-field')), findsOneWidget);
    final field = tester.widget<TextField>(find.byKey(const Key('search-field')));
    expect(field.focusNode!.hasFocus, isTrue);

    // Typing goes straight into the search box.
    await tester.enterText(find.byKey(const Key('search-field')), 'abc');
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('shortcuts also work with Cmd (macOS)', (tester) async {
    await pumpNudge(tester, startOnBoards: false);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada board. Buat yang pertama.'), findsOneWidget);
  });
}
