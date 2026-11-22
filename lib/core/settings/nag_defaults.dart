import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// Defaults applied to every new reminder (editable in Pengaturan).
class NagDefaultsState {
  const NagDefaultsState({
    this.intervalMinutes = 10,
    this.maxCount,
    this.escalate = true,
    this.quiet = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 7 * 60,
  });

  final int intervalMinutes;
  final int? maxCount;
  final bool escalate;
  final bool quiet;
  final int quietStart;
  final int quietEnd;

  NagDefaultsState copyWith({
    int? intervalMinutes,
    int? Function()? maxCount,
    bool? escalate,
    bool? quiet,
    int? quietStart,
    int? quietEnd,
  }) =>
      NagDefaultsState(
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        maxCount: maxCount == null ? this.maxCount : maxCount(),
        escalate: escalate ?? this.escalate,
        quiet: quiet ?? this.quiet,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
      );
}

class NagDefaultsNotifier extends Notifier<NagDefaultsState> {
  static const _interval = 'nag_default_interval';
  static const _max = 'nag_default_max';
  static const _escalate = 'nag_default_escalate';
  static const _quiet = 'nag_default_quiet';
  static const _qStart = 'nag_default_quiet_start';
  static const _qEnd = 'nag_default_quiet_end';

  @override
  NagDefaultsState build() {
    final p = ref.read(sharedPrefsProvider);
    const d = NagDefaultsState();
    return NagDefaultsState(
      intervalMinutes: p.getInt(_interval) ?? d.intervalMinutes,
      maxCount: p.getInt(_max),
      escalate: p.getBool(_escalate) ?? d.escalate,
      quiet: p.getBool(_quiet) ?? d.quiet,
      quietStart: p.getInt(_qStart) ?? d.quietStart,
      quietEnd: p.getInt(_qEnd) ?? d.quietEnd,
    );
  }

  Future<void> update(NagDefaultsState s) async {
    state = s;
    final p = ref.read(sharedPrefsProvider);
    await p.setInt(_interval, s.intervalMinutes);
    if (s.maxCount == null) {
      await p.remove(_max);
    } else {
      await p.setInt(_max, s.maxCount!);
    }
    await p.setBool(_escalate, s.escalate);
    await p.setBool(_quiet, s.quiet);
    await p.setInt(_qStart, s.quietStart);
    await p.setInt(_qEnd, s.quietEnd);
  }
}

final nagDefaultsProvider =
    NotifierProvider<NagDefaultsNotifier, NagDefaultsState>(
  NagDefaultsNotifier.new,
);
