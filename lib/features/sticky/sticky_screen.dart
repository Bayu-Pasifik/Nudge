import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/providers.dart';
import '../../core/db/repository.dart';
import '../../core/desktop/sticky_mode.dart';
import '../../core/theme/tokens.dart';

/// Compact always-on-top view of pinned cards: tick checklist items and finish
/// cards without opening the full app.
class StickyScreen extends ConsumerWidget {
  const StickyScreen({super.key, this.dragArea});

  /// Wraps the header so the borderless window can be dragged (desktop only).
  final Widget Function(Widget child)? dragArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final notes = ref.watch(stickyNotesProvider);
    final header = Container(
      height: 44,
      padding: const EdgeInsets.only(left: AppSpacing.md),
      color: t.bgList,
      child: Row(
        children: [
          Icon(Icons.push_pin, size: 16, color: t.accent),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text('Sticky', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            key: const Key('sticky-exit'),
            tooltip: 'Kembali ke jendela penuh',
            icon: const Icon(Icons.open_in_full, size: 18),
            onPressed: () => ref.read(stickyModeProvider.notifier).set(false),
          ),
        ],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          dragArea == null ? header : dragArea!(header),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) => items.isEmpty
                  ? Center(
                      key: const Key('sticky-empty'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Belum ada kartu ter-pin.\nPin kartu dari detailnya.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: t.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) =>
                          _StickyNote(key: ValueKey(items[i].open.card.id), info: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyNote extends ConsumerWidget {
  const _StickyNote({super.key, required this.info});
  final StickyInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = info.open.card;
    final c = StickyColors.byName(card.stickyColor);
    final repo = ref.read(repositoryProvider);
    const ink = Color(0xFF1E1B16); // sticky stays light in dark mode too

    return Container(
      decoration: BoxDecoration(
        color: c.fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.edge),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                key: Key('sticky-done-${card.title}'),
                value: false,
                shape: const CircleBorder(),
                side: const BorderSide(color: ink, width: 1.5),
                onChanged: (_) => repo.setCardCompleted(card.id, true),
              ),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          for (final item in info.items)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: Row(
                children: [
                  Checkbox(
                    key: Key('sticky-check-${item.text_}'),
                    value: item.done,
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: ink, width: 1.2),
                    onChanged: (v) =>
                        repo.setChecklistItemDone(item.id, v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      item.text_,
                      style: TextStyle(
                        color: ink,
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
