import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/app.dart';
import 'package:nudge/core/db/database.dart';
import 'package:nudge/core/db/providers.dart';

/// Pumps the app with a fresh in-memory DB.
Future<AppDatabase> pumpNudge(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const NudgeApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}
