import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import '../boards/boards_screen.dart' show confirmDialog;
import 'card_tile.dart';
import 'drag.dart';

class ListColumn extends ConsumerStatefulWidget {
  const ListColumn({
    super.key,
    required this.list,
    required this.cards,
    required this.checklistByCard,
  });

  final BoardList list;
  final List<TodoCard> cards;
  final Map<String, List<ChecklistItem>> checklistByCard;

  @override
  ConsumerState<ListColumn> createState() => _ListColumnState();
}

class _ListColumnState extends ConsumerState<ListColumn> {
  bool _adding = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Drop of [cardId] before the card at [index] (or at the end).
  Future<void> _drop(String cardId, int index) async {
    final current = widget.cards.indexWhere((c) => c.id == cardId);
    // Moving down inside the same list: the dragged card's own slot vanishes.
    final target = (current != -1 && current < index) ? index - 1 : index;
    if (current == target) return;
    await ref
        .read(repositoryProvider)
        .moveCard(cardId, widget.list.id, target);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _adding = false);
      return;
    }
    await ref.read(repositoryProvider).createCard(widget.list.id, text);
    _controller.clear();
    _focus.requestFocus(); // keep adding
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final list = widget.list;
    return Container(
      decoration: BoxDecoration(
        color: t.bgList,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: LongPressDraggable<ListDragData>(
                    key: Key('list-handle-${list.title}'),
                    data: ListDragData(list.id),
                    onDragStarted: () =>
                        ref.read(draggingProvider.notifier).set(true),
                    onDragEnd: (_) =>
                        ref.read(draggingProvider.notifier).set(false),
                    onDraggableCanceled: (_, _) =>
                        ref.read(draggingProvider.notifier).set(false),
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: t.bgList,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: t.accent),
                        ),
                        child: Text(
                          list.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(
                        list.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  '${widget.cards.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('list-menu-${list.title}'),
                  onSelected: (v) async {
                    final repo = ref.read(repositoryProvider);
                    if (v == 'rename') {
                      final name = await promptText(
                        context,
                        title: 'Ubah nama list',
                        initial: list.title,
                      );
                      if (name != null) await repo.renameList(list.id, name);
                    } else if (v == 'archive') {
                      final ok = await confirmDialog(
                        context,
                        title: 'Arsipkan list?',
                        message: 'List "${list.title}" akan disembunyikan.',
                        confirmLabel: 'Arsipkan',
                      );
                      if (ok) await repo.archiveList(list.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                    PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              // +1: trailing drop zone so cards can be dropped at the end
              // (and into an empty list).
              itemCount: widget.cards.length + 1,
              itemBuilder: (_, i) {
                if (i == widget.cards.length) {
                  return _DropSlot(
                    key: Key('drop-end-${list.title}'),
                    onDrop: (id) => _drop(id, i),
                    minHeight: widget.cards.isEmpty ? 56 : 32,
                  );
                }
                final c = widget.cards[i];
                return _DropSlot(
                  key: ValueKey('slot-${c.id}'),
                  onDrop: (id) => _drop(id, i),
                  child: _DraggableCard(
                    card: c,
                    checklist: widget.checklistByCard[c.id] ?? const [],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _adding
                ? TextField(
                    key: const Key('quick-add-field'),
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Judul kartu',
                      isDense: true,
                      suffixIcon: IconButton(
                        key: const Key('quick-add-submit'),
                        icon: const Icon(Icons.check),
                        onPressed: _submit,
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                    onTapOutside: (_) {
                      if (_controller.text.trim().isEmpty) {
                        setState(() => _adding = false);
                      }
                    },
                  )
                : SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      key: Key('add-card-${list.title}'),
                      onPressed: () => setState(() => _adding = true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Tambah kartu'),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: t.textSecondary,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a card slot: shows an insertion line while a card hovers and reports
/// the dropped card id.
class _DropSlot extends StatelessWidget {
  const _DropSlot({
    super.key,
    required this.onDrop,
    this.child,
    this.minHeight = 0,
  });

  final void Function(String cardId) onDrop;
  final Widget? child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CardDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onDrop(d.data.cardId),
      builder: (context, candidates, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InsertionLine(active: candidates.isNotEmpty),
            if (child != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: child,
              )
            else
              SizedBox(height: minHeight),
          ],
        );
      },
    );
  }
}

class _DraggableCard extends ConsumerWidget {
  const _DraggableCard({required this.card, required this.checklist});
  final TodoCard card;
  final List<ChecklistItem> checklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void setDragging(bool v) => ref.read(draggingProvider.notifier).set(v);
    final tile = CardTile(card: card, checklist: checklist);
    return LongPressDraggable<CardDragData>(
      data: CardDragData(card.id),
      onDragStarted: () => setDragging(true),
      onDragEnd: (_) => setDragging(false),
      onDraggableCanceled: (_, _) => setDragging(false),
      feedback: Material(
        color: Colors.transparent,
        child: Transform.rotate(
          angle: 0.035,
          child: SizedBox(
            width: 280,
            child: Opacity(opacity: 0.95, child: tile),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}

/// Small text prompt dialog. Returns trimmed text, or null if cancelled/empty.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String label = 'Nama',
}) async {
  final controller = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('prompt-field'),
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (_) => Navigator.pop(ctx, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('prompt-save'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  final text = controller.text.trim();
  if (ok != true || text.isEmpty) return null;
  return text;
}
