import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches on Today, Boards tab shows empty state',
      (tester) async {
    await pumpNudge(tester, startOnBoards: false);
    expect(find.text('Hari ini'), findsWidgets);
    expect(find.text('Tidak ada yang mendesak hari ini.'), findsOneWidget);

    await pumpNudge(tester); // fresh app, switched to the Boards tab
    expect(find.text('Belum ada board. Buat yang pertama.'), findsOneWidget);
  });
}
