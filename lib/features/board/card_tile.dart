import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/format.dart';

class CardTile extends ConsumerWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.checklist,
  });

  final TodoCard card;
  final List<ChecklistItem> checklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final done = card.completedAt != null;
    final status = dueStatus(card.dueAt, completed: done);
    final doneItems = checklist.where((i) => i.done).length;

    // Pinned cards look like a sticky note: pastel fill with dark text.
    final sticky = card.pinned ? StickyColors.byName(card.stickyColor) : null;
    const stickyText = Color(0xFF1E1B16);
    return Material(
      color: sticky?.fill ?? t.bgSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/card/${card.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: status == DueStatus.overdue
                  ? t.danger
                  : (sticky?.edge ?? t.border),
              width: status == DueStatus.overdue ? 1.5 : 1,
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
                  key: Key('complete-${card.title}'),
                  value: done,
                  shape: const CircleBorder(),
                  activeColor: t.success,
                  onChanged: (v) => ref
                      .read(repositoryProvider)
                      .setCardCompleted(card.id, v ?? false),
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
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 22 / 15,
                          color: done
                              ? t.textSecondary
                              : (sticky != null ? stickyText : t.textPrimary),
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (card.dueAt != null ||
                          checklist.isNotEmpty ||
                          card.pinned) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (card.pinned)
                              Icon(Icons.push_pin, size: 14, color: t.accent),
                            if (card.dueAt != null)
                              _Chip(
                                icon: Icons.schedule,
                                label: formatDue(card.dueAt!),
                                color: switch (status) {
                                  DueStatus.overdue => t.danger,
                                  DueStatus.today => t.warning,
                                  DueStatus.done => t.success,
                                  _ => t.textSecondary,
                                },
                              ),
                            if (checklist.isNotEmpty)
                              _Chip(
                                icon: Icons.checklist,
                                label: '$doneItems/${checklist.length}',
                                color: doneItems == checklist.length
                                    ? t.success
                                    : t.textSecondary,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
