// Build and run the real code paths in a RELEASE build (R8 shrinking, no debug
// assertions) and report to logcat:
//
//   flutter build apk --release -t tool/release_check_main.dart
//   adb install -r build/app/outputs/flutter-apk/app-release.apk
//   adb shell pm grant com.bayu.nudge android.permission.POST_NOTIFICATIONS
//   adb shell am start -n com.bayu.nudge/.MainActivity
//   adb logcat -d | grep RELEASE_CHECK
// ignore_for_file: avoid_print
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/repository.dart';
import 'package:nudge/core/nag/local_notifications_gateway.dart';
import 'package:nudge/core/nag/nag_scheduler.dart';
import 'package:nudge/core/widget/home_widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('release check')))));

  Future<void> step(String name, Future<Object?> Function() body) async {
    try {
      final r = await body();
      print('RELEASE_CHECK ok   $name${r == null ? '' : ' -> $r'}');
    } catch (e, st) {
      print('RELEASE_CHECK FAIL $name: $e\n$st');
    }
  }

  final gateway = LocalNotificationsGateway();
  await step('gateway.init', () async {
    await gateway.init();
    return null;
  });
  await step('notifications allowed', gateway.notificationsAllowed);

  late AppDatabase db;
  late Repository repo;
  await step('database opens', () async {
    db = AppDatabase();
    repo = Repository(db);
    return (await db.select(db.boards).get()).length;
  });

  String? cardId;
  await step('create board/list/card/reminder', () async {
    final b = await repo.createBoard('Release');
    final l = await repo.createList(b, 'Todo');
    cardId = await repo.createCard(l, 'Kartu rilis');
    await repo.updateCard(cardId!, pinned: true);
    await repo.addReminder(
      cardId!,
      DateTime.now().add(const Duration(seconds: 20)),
      intervalMinutes: 5,
      maxCount: 3,
    );
    return cardId;
  });

  final scheduler = NagScheduler(repo, gateway, onPinned: updateHomeWidget);
  await step('scheduler.rescheduleAll', () async {
    await scheduler.rescheduleAll();
    return null;
  });
  await step('pending nags', () async => (await gateway.pendingNags()).length);
  await step('sticky shown', () async => (await gateway.activeTitles()).join(','));
  await step('home widget data', () async {
    await updateHomeWidget(await repo.pinnedStickies());
    return null;
  });
  print('RELEASE_CHECK done');
}
