import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/nag/providers.dart';
import '../../core/settings/nag_defaults.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import 'reminder_sheet.dart';

final remindersProvider =
    StreamProvider.autoDispose.family<List<Reminder>, String>(
  (ref, cardId) => ref.watch(repositoryProvider).watchReminders(cardId),
);

class RemindersSection extends ConsumerWidget {
  const RemindersSection({super.key, required this.card});
  final TodoCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final reminders = ref.watch(remindersProvider(card.id)).value ?? const [];
    final repo = ref.read(repositoryProvider);

    Future<void> add() async {
      final draft = await showReminderSheet(
        context,
        defaults: ref.read(nagDefaultsProvider),
      );
      if (draft == null) return;
      // Ask for notification permission the first time it matters.
      final gateway = ref.read(notificationGatewayProvider);
      if (!await gateway.notificationsAllowed()) {
        await gateway.requestPermissions();
      }
      await repo.addReminder(
        card.id,
        draft.remindAt,
        nagEnabled: draft.nagEnabled,
        intervalMinutes: draft.intervalMinutes,
        maxCount: draft.maxCount,
        escalationJson: draft.escalationJson,
        quietStartMinute: draft.quiet ? draft.quietStart : null,
        quietEndMinute: draft.quiet ? draft.quietEnd : null,
      );
    }

    Future<void> edit(Reminder r) async {
      final draft = await showReminderSheet(
        context,
        initial: ReminderDraft(
          remindAt: r.remindAt,
          nagEnabled: r.nagEnabled,
          intervalMinutes: r.nagIntervalMinutes,
          maxCount: r.nagMaxCount,
          escalate: r.escalation != null,
          quiet: r.quietStartMinute != null,
          quietStart: r.quietStartMinute ?? NagDefaults.quietStart,
          quietEnd: r.quietEndMinute ?? NagDefaults.quietEnd,
        ),
      );
      if (draft == null) return;
      await repo.updateReminder(
        r.id,
        remindAt: draft.remindAt,
        nagEnabled: draft.nagEnabled,
        intervalMinutes: draft.intervalMinutes,
        maxCount: Value(draft.maxCount),
        escalationJson: Value(draft.escalationJson),
        quietStartMinute: Value(draft.quiet ? draft.quietStart : null),
        quietEndMinute: Value(draft.quiet ? draft.quietEnd : null),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in reminders)
          Card(
            key: Key('reminder-${r.id}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            elevation: 0,
            color: t.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: t.border),
            ),
            child: ListTile(
              onTap: () => edit(r),
              leading: Icon(
                r.nagEnabled ? Icons.notifications_active : Icons.notifications,
                color: switch (r.state) {
                  'missed' => t.danger,
                  'nagging' => t.warning,
                  _ => t.accent,
                },
              ),
              title: Text(formatDue(r.remindAt)),
              subtitle: Text(_summary(r)),
              trailing: IconButton(
                key: Key('delete-reminder-${r.id}'),
                tooltip: 'Hapus pengingat',
                icon: const Icon(Icons.close),
                onPressed: () => repo.deleteReminder(r.id),
              ),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('add-reminder'),
          onPressed: add,
          icon: const Icon(Icons.add_alarm),
          label: const Text('Tambah pengingat'),
        ),
      ],
    );
  }

  String _summary(Reminder r) {
    final parts = <String>[];
    if (r.state == 'missed') parts.add('Terlewat');
    if (r.state == 'nagging') parts.add('Sedang mengingatkan');
    if (!r.nagEnabled) {
      parts.add('Sekali saja');
    } else {
      parts.add('Ulang tiap ${r.nagIntervalMinutes} mnt');
      if (r.nagMaxCount != null) parts.add('maks ${r.nagMaxCount}×');
      if (r.escalation != null) parts.add('makin mendesak');
    }
    return parts.join(' · ');
  }
}
