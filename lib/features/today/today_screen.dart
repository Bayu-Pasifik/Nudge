import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/providers.dart';
import '../../core/nag/providers.dart';
import '../../core/settings/prefs.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';
import 'today_data.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(openCardsProvider);
    final reminders = ref.watch(activeRemindersProvider);
    final paused = ref.watch(pausedUntilProvider);
    final t = context.tokens;

    final items = (cards.hasValue && reminders.hasValue)
        ? buildToday(
            cards.value!,
            [for (final a in reminders.value!) a.reminder],
            now: DateTime.now(),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hari ini'),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          PopupMenuButton<String>(
            key: const Key('pause-menu'),
            icon: Icon(paused == null ? Icons.notifications_active_outlined : Icons.notifications_paused),
            tooltip: 'Jeda pengingat',
            onSelected: (v) {
              final n = ref.read(pausedUntilProvider.notifier);
              final now = DateTime.now();
              switch (v) {
                case '1h':
                  n.pauseFor(const Duration(hours: 1));
                case 'tomorrow':
                  n.pauseUntil(DateTime(now.year, now.month, now.day + 1, 7));
                case 'resume':
                  n.resume();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: '1h',
                key: Key('pause-1h'),
                child: Text('Jeda 1 jam'),
              ),
              const PopupMenuItem(
                value: 'tomorrow',
                key: Key('pause-tomorrow'),
                child: Text('Jeda sampai besok pagi'),
              ),
              if (paused != null)
                const PopupMenuItem(
                  value: 'resume',
                  key: Key('resume'),
                  child: Text('Lanjutkan pengingat'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const _PermissionBanner(),
          if (paused != null) _PausedBanner(until: paused),
          Expanded(
            child: items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        key: const Key('today-empty'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48, color: t.success),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Tidak ada yang mendesak hari ini.',
                              style: TextStyle(color: t.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : _TodayList(items: items),
          ),
        ],
      ),
    );
  }
}

class _TodayList extends StatelessWidget {
  const _TodayList({required this.items});
  final List<TodayItem> items;

  static const _titles = {
    TodayGroup.overdue: 'Terlewat',
    TodayGroup.nagging: 'Sedang mengingatkan',
    TodayGroup.today: 'Hari ini',
    TodayGroup.pinned: 'Ter-pin',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final children = <Widget>[];
    TodayGroup? last;
    for (final i in items) {
      if (i.group != last) {
        last = i.group;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              _titles[i.group]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: switch (i.group) {
                  TodayGroup.overdue => t.danger,
                  TodayGroup.nagging => t.warning,
                  _ => t.textSecondary,
                },
              ),
            ),
          ),
        );
      }
      children.add(_TodayTile(key: ValueKey(i.card.id), item: i));
      children.add(const SizedBox(height: AppSpacing.sm));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: children,
    );
  }
}

class _TodayTile extends ConsumerWidget {
  const _TodayTile({super.key, required this.item});
  final TodayItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final card = item.card;
    final r = item.nextReminder;
    final status = dueStatus(card.dueAt, completed: false);
    final accent = switch (item.group) {
      TodayGroup.overdue => t.danger,
      TodayGroup.nagging => t.warning,
      _ => t.border,
    };
    return Material(
      color: t.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/card/${card.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: accent,
              width: item.group == TodayGroup.pinned ? 1 : 1.5,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Checkbox(
                  key: Key('today-complete-${card.title}'),
                  value: false,
                  shape: const CircleBorder(),
                  activeColor: t.success,
                  onChanged: (_) => ref
                      .read(repositoryProvider)
                      .setCardCompleted(card.id, true),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(fontSize: 15, height: 22 / 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.open.boardTitle} › ${item.open.listTitle}',
                        style: TextStyle(fontSize: 13, color: t.textSecondary),
                      ),
                      if (card.dueAt != null || r != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          children: [
                            if (card.dueAt != null)
                              _Meta(
                                Icons.schedule,
                                formatDue(card.dueAt!),
                                status == DueStatus.overdue
                                    ? t.danger
                                    : status == DueStatus.today
                                        ? t.warning
                                        : t.textSecondary,
                              ),
                            if (r != null)
                              _Meta(
                                r.state == 'missed'
                                    ? Icons.notifications_off
                                    : Icons.notifications_active,
                                r.state == 'missed'
                                    ? 'Terlewat · ${formatDue(r.remindAt)}'
                                    : formatDue(r.remindAt),
                                r.state == 'missed' ? t.danger : t.textSecondary,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      );
}

class _PausedBanner extends ConsumerWidget {
  const _PausedBanner({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final hm =
        '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';
    return Container(
      key: const Key('paused-banner'),
      width: double.infinity,
      color: t.accentSoft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_paused, color: t.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Pengingat dijeda sampai ${formatDue(until)} $hm')),
          TextButton(
            key: const Key('resume-banner'),
            onPressed: () => ref.read(pausedUntilProvider.notifier).resume(),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }
}

/// Warns when notifications are blocked: reminders would silently not ring.
class _PermissionBanner extends ConsumerStatefulWidget {
  const _PermissionBanner();

  @override
  ConsumerState<_PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends ConsumerState<_PermissionBanner>
    with WidgetsBindingObserver {
  bool _allowed = true;

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
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final ok = await ref.read(notificationGatewayProvider).notificationsAllowed();
    if (mounted && ok != _allowed) setState(() => _allowed = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) return const SizedBox.shrink();
    final t = context.tokens;
    return Container(
      key: const Key('perm-banner'),
      width: double.infinity,
      color: t.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: t.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text('Notifikasi dimatikan. Pengingat tidak akan berbunyi.'),
          ),
          TextButton(
            key: const Key('perm-enable'),
            onPressed: () async {
              await ref.read(notificationGatewayProvider).requestPermissions();
              await _check();
            },
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
  }
}
