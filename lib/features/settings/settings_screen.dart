import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_providers.dart';
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
