import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches into an empty boards screen', (tester) async {
    await pumpNudge(tester);
    expect(find.text('Board'), findsOneWidget);
    expect(find.text('Belum ada board. Buat yang pertama.'), findsOneWidget);
  });
}
