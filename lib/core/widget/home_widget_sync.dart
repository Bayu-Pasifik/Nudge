import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../nag/local_notifications_gateway.dart';
import '../nag/nag_actions.dart';
import '../nag/nag_scheduler.dart';
import '../nag/notification_gateway.dart';
import '../settings/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Must match the Kotlin class `com.bayu.nudge.NudgeWidgetProvider`.
const widgetProviderName = 'com.bayu.nudge.NudgeWidgetProvider';

/// Rows the widget layout can show.
const widgetMaxRows = 5;

/// What the widget renders for one pinned card.
class WidgetRow {
  const WidgetRow(this.cardId, this.title);
  final String cardId;
  final String title;
}

List<WidgetRow> widgetRowsFrom(List<StickyInfo> pinned) => [
      for (final s in pinned.take(widgetMaxRows))
        WidgetRow(s.open.card.id, s.open.card.title),
    ];

/// Pushes the pinned cards to the Android home screen widget. Never throws:
/// a missing widget or platform must not break scheduling.
Future<void> updateHomeWidget(List<StickyInfo> pinned) async {
  try {
    final rows = widgetRowsFrom(pinned);
    await HomeWidget.saveWidgetData<int>('count', rows.length);
    for (var i = 0; i < widgetMaxRows; i++) {
      await HomeWidget.saveWidgetData<String>(
        'id_$i',
        i < rows.length ? rows[i].cardId : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'title_$i',
        i < rows.length ? rows[i].title : '',
      );
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: widgetProviderName);
  } catch (e) {
    debugPrint('home widget update failed: $e');
  }
}

/// Runs in a background isolate when the widget's tick button is pressed
/// (`nudge://done/<cardId>`): completes the card, re-syncs notifications and
/// refreshes the widget, all without opening the app.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.scheme != 'nudge' || uri.host != 'done') return;
  final cardId = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  if (cardId == null || cardId.isEmpty) return;

  final gateway = LocalNotificationsGateway();
  await gateway.init();
  final db = AppDatabase();
  final repo = Repository(db);
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  try {
    final scheduler = NagScheduler(
      repo,
      gateway,
      pausedUntil: () => readPausedUntil(prefs),
      onPinned: updateHomeWidget,
    );
    await handleNagAction(repo, scheduler, NagAction.done, NagPayload('', cardId));
  } finally {
    await db.close();
  }
}

/// `nudge://card/<id>` from a widget title tap -> card id.
String? cardIdFromWidgetUri(Uri? uri) {
  if (uri == null || uri.scheme != 'nudge' || uri.host != 'card') return null;
  return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
}
