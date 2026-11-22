import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import '../boards/boards_screen.dart' show confirmDialog;
import 'card_tile.dart';

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
                  child: Text(
                    list.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              itemCount: widget.cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = widget.cards[i];
                return CardTile(
                  key: ValueKey(c.id),
                  card: c,
                  checklist: widget.checklistByCard[c.id] ?? const [],
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
