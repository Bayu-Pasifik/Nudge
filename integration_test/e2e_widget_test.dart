import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/nag_scheduler.dart';
import 'package:nudge/core/widget/home_widget_sync.dart';

/// Real Android home screen widget. Needs tool/drive_widget.ps1 to add the
/// widget to the home screen and press its tick button:
///   flutter test integration_test/e2e_widget_test.dart --dart-define=NUDGE_E2E=true -d emulator-5554
const _e2e = bool.fromEnvironment('NUDGE_E2E');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen widget shows pinned cards and the tick completes one',
      (tester) async {
    await tester.runAsync(() async {
      final gateway = LocalNotificationsGateway();
      await gateway.init();
      final db = AppDatabase();
      final repo = Repository(db);
      final scheduler = NagScheduler(repo, gateway, onPinned: updateHomeWidget);

      final board = await repo.createBoard('Widget');
      final list = await repo.createList(board, 'Todo');
      final a = await repo.createCard(list, 'Widget kartu satu');
      final b = await repo.createCard(list, 'Widget kartu dua');
      await repo.updateCard(a, pinned: true);
      await repo.updateCard(b, pinned: true);
      await scheduler.rescheduleAll();

      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
      // ignore: avoid_print
      print('E2E: widget data pushed, requesting pin');
      await HomeWidget.requestPinWidget(qualifiedAndroidName: widgetProviderName);

      // The driver adds the widget, then presses the tick of the first row.
      final end = DateTime.now().add(const Duration(seconds: 150));
      var completed = 0;
      while (DateTime.now().isBefore(end)) {
        final cards = await db.select(db.cards).get();
        completed = cards.where((c) => c.completedAt != null).length;
        if (completed > 0) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(completed, 1, reason: 'exactly one card ticked from the widget');
      // ignore: avoid_print
      print('E2E: widget tick OK');

      // The widget data now lists only the remaining pinned card.
      final count = await HomeWidget.getWidgetData<int>('count');
      expect(count, 1);
      await db.close();
    });
  }, skip: !_e2e);
}
