import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/auth/auth_providers.dart';
import '../../core/db/providers.dart';
import '../../core/export/export_service.dart';
import '../../core/nag/providers.dart';
import '../../core/platform/system_settings.dart';
import '../../core/settings/nag_defaults.dart';
import '../../core/settings/theme_mode.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/theme/tokens.dart';
import '../boards/boards_screen.dart' show confirmDialog;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final session = ref.watch(authSessionProvider);
    final sync = ref.watch(syncControllerProvider);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const _Header('Akun'),
          if (!session.configured)
            ListTile(
              key: const Key('local-mode'),
              leading: const Icon(Icons.cloud_off),
              title: const Text('Mode lokal'),
              subtitle: const Text(
                'Data hanya ada di perangkat ini. Hubungkan Supabase untuk '
                'sinkron antar perangkat.',
              ),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(session.email ?? 'Masuk'),
              subtitle: const Text('Data tersimpan di Supabase'),
            ),
            ListTile(
              key: const Key('sync-status'),
              leading: Icon(
                switch (sync.state) {
                  SyncState.syncing => Icons.sync,
                  SyncState.offline || SyncState.error => Icons.cloud_off,
                  _ => Icons.cloud_done_outlined,
                },
                color: switch (sync.state) {
                  SyncState.offline || SyncState.error => t.danger,
                  _ => t.success,
                },
              ),
              title: Text(switch (sync.state) {
                SyncState.syncing => 'Menyinkronkan…',
                SyncState.offline => 'Offline',
                SyncState.error => 'Gagal menyinkronkan',
                SyncState.idle => sync.enabled ? 'Tersinkron' : 'Sinkron mati',
              }),
              subtitle: Text(
                sync.state == SyncState.offline
                    ? 'Perubahan disimpan dan akan dikirim saat online.'
                    : sync.lastSync == null
                        ? 'Belum pernah'
                        : 'Terakhir ${_hm(sync.lastSync!)}',
              ),
              trailing: TextButton(
                key: const Key('sync-now'),
                onPressed: () =>
                    ref.read(syncControllerProvider.notifier).syncNow(),
                child: const Text('Sinkronkan'),
              ),
            ),
            ListTile(
              key: const Key('sign-out'),
              leading: Icon(Icons.logout, color: t.danger),
              title: Text('Keluar', style: TextStyle(color: t.danger)),
              subtitle: const Text('Data di perangkat ini akan dihapus'),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Keluar?',
                  message:
                      'Perubahan dikirim dulu ke server, lalu data di perangkat '
                      'ini dihapus. Kamu bisa masuk lagi kapan saja.',
                  confirmLabel: 'Keluar',
                  destructive: true,
                );
                if (ok) {
                  await ref.read(syncControllerProvider.notifier).signOutAndWipe();
                }
              },
            ),
          ],
          if (Platform.isAndroid) ...[
            const SizedBox(height: AppSpacing.lg),
            const _Header('Agar pengingat selalu bunyi'),
            const _ReliabilityGuide(),
          ],
          const SizedBox(height: AppSpacing.lg),
          const _Header('Pengingat default'),
          const _NagDefaultsSection(),
          const SizedBox(height: AppSpacing.lg),
          const _Header('Data'),
          ListTile(
            key: const Key('export-json'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Ekspor data (JSON)'),
            subtitle: const Text('Cadangan semua board, kartu, checklist, dan pengingat'),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await exportAll(ref.read(appDatabaseProvider));
              await Clipboard.setData(ClipboardData(text: result.json));
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Diekspor dan disalin ke clipboard.\n${result.path}',
                    key: const Key('export-done'),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          const _Header('Tampilan'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('Sistem', key: Key('theme-system')),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Terang', key: Key('theme-light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Gelap', key: Key('theme-dark')),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
        ],
      ),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Android: the three settings that decide whether reminders ring when the app
/// is closed.
class _ReliabilityGuide extends ConsumerStatefulWidget {
  const _ReliabilityGuide();

  @override
  ConsumerState<_ReliabilityGuide> createState() => _ReliabilityGuideState();
}

class _ReliabilityGuideState extends ConsumerState<_ReliabilityGuide>
    with WidgetsBindingObserver {
  bool? _allowed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings screen: re-read the permission.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final ok = await ref.read(notificationGatewayProvider).notificationsAllowed();
    if (mounted) setState(() => _allowed = ok);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final launcher = ref.read(systemSettingsProvider);
    final allowed = _allowed;
    return Column(
      children: [
        ListTile(
          key: const Key('guide-notifications'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            allowed == false ? Icons.notifications_off : Icons.notifications_active,
            color: allowed == false ? t.danger : t.success,
          ),
          title: const Text('Notifikasi'),
          subtitle: Text(
            allowed == false
                ? 'Dimatikan. Pengingat tidak akan berbunyi.'
                : 'Aktif',
          ),
          trailing: TextButton(
            key: const Key('open-notification-settings'),
            onPressed: launcher.openNotificationSettings,
            child: const Text('Buka'),
          ),
        ),
        ListTile(
          key: const Key('guide-battery'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.battery_saver, color: t.warning),
          title: const Text('Penghemat baterai'),
          subtitle: const Text(
            'Pilih Nudge lalu "Tidak dibatasi" supaya pengingat tetap jalan '
            'saat app ditutup.',
          ),
          trailing: TextButton(
            key: const Key('open-battery-settings'),
            onPressed: launcher.openBatteryOptimization,
            child: const Text('Buka'),
          ),
        ),
        ListTile(
          key: const Key('guide-brand'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.phone_android, color: t.textSecondary),
          title: const Text('Xiaomi, Oppo, Vivo, Samsung'),
          subtitle: const Text(
            'Aktifkan "Autostart" / "Jalankan di latar belakang" untuk Nudge '
            'di pengaturan app.',
          ),
          trailing: TextButton(
            key: const Key('open-app-details'),
            onPressed: launcher.openAppDetails,
            child: const Text('Buka'),
          ),
        ),
      ],
    );
  }
}

/// Defaults applied to every newly created reminder.
class _NagDefaultsSection extends ConsumerWidget {
  const _NagDefaultsSection();

  static const _intervals = [1, 5, 10, 15, 30, 60];
  static const _maxCounts = <int?>[null, 5, 10, 20, 50];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final d = ref.watch(nagDefaultsProvider);
    final n = ref.read(nagDefaultsProvider.notifier);

    String hm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    Future<void> pick(bool start) async {
      final cur = start ? d.quietStart : d.quietEnd;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      );
      if (time == null) return;
      final m = time.hour * 60 + time.minute;
      await n.update(start ? d.copyWith(quietStart: m) : d.copyWith(quietEnd: m));
    }

    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
          child: Text(
            s,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('Ulangi setiap'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final m in _intervals)
              ChoiceChip(
                key: Key('default-interval-$m'),
                label: Text(m == 60 ? '1 jam' : '$m mnt'),
                selected: d.intervalMinutes == m,
                onSelected: (_) => n.update(d.copyWith(intervalMinutes: m)),
              ),
          ],
        ),
        label('Maksimum pengingat'),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final c in _maxCounts)
              ChoiceChip(
                key: Key('default-max-${c ?? 'inf'}'),
                label: Text(c == null ? 'Sampai selesai' : '$c kali'),
                selected: d.maxCount == c,
                onSelected: (_) => n.update(d.copyWith(maxCount: () => c)),
              ),
          ],
        ),
        SwitchListTile(
          key: const Key('default-escalate'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Makin mendesak bila diabaikan'),
          value: d.escalate,
          onChanged: (v) => n.update(d.copyWith(escalate: v)),
        ),
        SwitchListTile(
          key: const Key('default-quiet'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Jam tenang'),
          subtitle: Text('Tidak mengulang pukul ${hm(d.quietStart)}–${hm(d.quietEnd)}'),
          value: d.quiet,
          onChanged: (v) => n.update(d.copyWith(quiet: v)),
        ),
        if (d.quiet)
          Row(
            children: [
              OutlinedButton(
                key: const Key('default-quiet-start'),
                onPressed: () => pick(true),
                child: Text('Mulai ${hm(d.quietStart)}'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                key: const Key('default-quiet-end'),
                onPressed: () => pick(false),
                child: Text('Selesai ${hm(d.quietEnd)}'),
              ),
            ],
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.tokens.textSecondary,
          ),
        ),
      );
}
