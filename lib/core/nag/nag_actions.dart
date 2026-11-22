import '../db/repository.dart';
import 'nag_scheduler.dart';
import 'notification_gateway.dart';

const snoozeMinutes = 10;

/// Applies a notification button press. Shared by the foreground handler and
/// the background isolate so behaviour is identical everywhere.
///
/// [NagAction.open] is navigation only and handled by the UI.
Future<void> handleNagAction(
  Repository repo,
  NagScheduler scheduler,
  NagAction action,
  NagPayload payload, {
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  switch (action) {
    case NagAction.done:
      await repo.setCardCompleted(payload.cardId, true);
    case NagAction.snooze:
      await repo.snoozeCardReminders(
        payload.cardId,
        now.add(const Duration(minutes: snoozeMinutes)),
      );
    case NagAction.open:
      return;
  }
  // Remove the rest of the sequence (done) or move it (snooze).
  await scheduler.rescheduleAll();
}
