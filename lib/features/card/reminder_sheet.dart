import 'package:material_ui/material_ui.dart';

import '../../core/nag/nag_plan.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';

/// Defaults for a new reminder (Pengaturan can override these later).
class NagDefaults {
  static const intervalMinutes = 10;
  static const quietStart = 22 * 60;
  static const quietEnd = 7 * 60;
}

class ReminderDraft {
  ReminderDraft({
    required this.remindAt,
    this.nagEnabled = true,
    this.intervalMinutes = NagDefaults.intervalMinutes,
    this.maxCount,
    this.escalate = true,
    this.quiet = true,
    this.quietStart = NagDefaults.quietStart,
    this.quietEnd = NagDefaults.quietEnd,
  });

  DateTime remindAt;
  bool nagEnabled;
  int intervalMinutes;
  int? maxCount;
  bool escalate;
  bool quiet;
  int quietStart;
  int quietEnd;

  String? get escalationJson => escalate ? encodeEscalation(defaultEscalation) : null;
}

const _intervals = [1, 5, 10, 15, 30, 60];
const _maxCounts = <int?>[null, 5, 10, 20, 50];

String fmtMinute(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Bottom sheet to create or edit a reminder. Returns null if dismissed.
Future<ReminderDraft?> showReminderSheet(
  BuildContext context, {
  ReminderDraft? initial,
}) {
  return showModalBottomSheet<ReminderDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReminderSheet(initial: initial),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.initial});
  final ReminderDraft? initial;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late final ReminderDraft _d = widget.initial ??
      ReminderDraft(remindAt: DateTime.now().add(const Duration(minutes: 10)));

  void _set(DateTime when) => setState(() => _d.remindAt = when);

  Future<void> _pickCustom() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _d.remindAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_d.remindAt),
    );
    if (time == null) return;
    _set(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickQuiet(bool start) async {
    final cur = start ? _d.quietStart : _d.quietEnd;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (time == null) return;
    setState(() {
      final m = time.hour * 60 + time.minute;
      if (start) {
        _d.quietStart = m;
      } else {
        _d.quietEnd = m;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final tonight = DateTime(now.year, now.month, now.day, 19);
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 8);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initial == null ? 'Pengingat baru' : 'Ubah pengingat',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                ActionChip(
                  key: const Key('preset-10m'),
                  label: const Text('10 menit lagi'),
                  onPressed: () => _set(now.add(const Duration(minutes: 10))),
                ),
                ActionChip(
                  key: const Key('preset-1h'),
                  label: const Text('1 jam lagi'),
                  onPressed: () => _set(now.add(const Duration(hours: 1))),
                ),
                if (tonight.isAfter(now))
                  ActionChip(
                    key: const Key('preset-tonight'),
                    label: const Text('Nanti malam'),
                    onPressed: () => _set(tonight),
                  ),
                ActionChip(
                  key: const Key('preset-tomorrow'),
                  label: const Text('Besok pagi'),
                  onPressed: () => _set(tomorrow),
                ),
                ActionChip(
                  key: const Key('preset-custom'),
                  avatar: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Pilih sendiri'),
                  onPressed: _pickCustom,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              key: const Key('reminder-when'),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: t.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.alarm, color: t.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _full(_d.remindAt),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              key: const Key('nag-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ingatkan terus sampai selesai'),
              subtitle: const Text('Notifikasi berulang selama belum dicentang'),
              value: _d.nagEnabled,
              onChanged: (v) => setState(() => _d.nagEnabled = v),
            ),
            if (_d.nagEnabled) ...[
              const _Label('Ulangi setiap'),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final m in _intervals)
                    ChoiceChip(
                      key: Key('interval-$m'),
                      label: Text(m == 60 ? '1 jam' : '$m mnt'),
                      selected: _d.intervalMinutes == m,
                      onSelected: (_) => setState(() => _d.intervalMinutes = m),
                    ),
                ],
              ),
              const _Label('Maksimum pengingat'),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final c in _maxCounts)
                    ChoiceChip(
                      key: Key('max-${c ?? 'inf'}'),
                      label: Text(c == null ? 'Sampai selesai' : '$c kali'),
                      selected: _d.maxCount == c,
                      onSelected: (_) => setState(() => _d.maxCount = c),
                    ),
                ],
              ),
              SwitchListTile(
                key: const Key('escalate-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Makin mendesak bila diabaikan'),
                subtitle: const Text(
                  'Ke-4: suara keras · ke-7: peringatan layar penuh',
                ),
                value: _d.escalate,
                onChanged: (v) => setState(() => _d.escalate = v),
              ),
              SwitchListTile(
                key: const Key('quiet-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Jam tenang'),
                subtitle: Text(
                  'Tidak mengulang pukul ${fmtMinute(_d.quietStart)}–${fmtMinute(_d.quietEnd)}',
                ),
                value: _d.quiet,
                onChanged: (v) => setState(() => _d.quiet = v),
              ),
              if (_d.quiet)
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _pickQuiet(true),
                      child: Text('Mulai ${fmtMinute(_d.quietStart)}'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => _pickQuiet(false),
                      child: Text('Selesai ${fmtMinute(_d.quietEnd)}'),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save-reminder'),
                onPressed: () => Navigator.pop(context, _d),
                child: const Text('Simpan pengingat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _full(DateTime d) {
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final label = formatDue(d);
    return label.contains(':') ? label : '$label $hm';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.tokens.textSecondary,
          ),
        ),
      );
}
