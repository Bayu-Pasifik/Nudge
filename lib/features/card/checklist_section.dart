import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';

class ChecklistSection extends ConsumerStatefulWidget {
  const ChecklistSection({super.key, required this.card});
  final TodoCard card;

  @override
  ConsumerState<ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends ConsumerState<ChecklistSection> {
  final _add = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submitNew() async {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    await ref.read(repositoryProvider).addChecklistItem(widget.card.id, text);
    _add.clear();
    _addFocus.requestFocus(); // rapid entry
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = ref.watch(checklistProvider(widget.card.id)).value ?? const [];
    final done = items.where((i) => i.done).length;
    final repo = ref.read(repositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '$done/${items.length}',
                key: const Key('checklist-progress'),
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: done / items.length,
                    minHeight: 6,
                    backgroundColor: t.bgHover,
                    color: done == items.length ? t.success : t.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final item in items)
          _ChecklistRow(key: ValueKey(item.id), item: item),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('checklist-add-field'),
          controller: _add,
          focusNode: _addFocus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Tambah item',
            isDense: true,
            suffixIcon: IconButton(
              key: const Key('checklist-add-submit'),
              icon: const Icon(Icons.add),
              onPressed: _submitNew,
            ),
          ),
          onSubmitted: (_) => _submitNew(),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          key: const Key('auto-complete-switch'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Selesaikan kartu otomatis'),
          subtitle: const Text('Saat semua item tercentang'),
          value: widget.card.autoCompleteOnChecklist,
          onChanged: (v) => repo.updateCard(
            widget.card.id,
            autoCompleteOnChecklist: v,
          ),
        ),
      ],
    );
  }
}

class _ChecklistRow extends ConsumerStatefulWidget {
  const _ChecklistRow({super.key, required this.item});
  final ChecklistItem item;

  @override
  ConsumerState<_ChecklistRow> createState() => _ChecklistRowState();
}

class _ChecklistRowState extends ConsumerState<_ChecklistRow> {
  late final TextEditingController _c =
      TextEditingController(text: widget.item.text_);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(covariant _ChecklistRow old) {
    super.didUpdateWidget(old);
    // Reflect remote edits unless the user is typing here.
    if (!_focus.hasFocus && old.item.text_ != widget.item.text_) {
      _c.text = widget.item.text_;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final v = _c.text.trim();
    if (v.isEmpty) {
      _c.text = widget.item.text_;
      return;
    }
    if (v != widget.item.text_) {
      ref.read(repositoryProvider).editChecklistItem(widget.item.id, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final item = widget.item;
    final repo = ref.read(repositoryProvider);
    return Row(
      children: [
        Checkbox(
          key: Key('check-${item.text_}'),
          value: item.done,
          activeColor: t.success,
          onChanged: (v) => repo.setChecklistItemDone(item.id, v ?? false),
        ),
        Expanded(
          child: TextField(
            key: Key('check-text-${item.text_}'),
            controller: _c,
            focusNode: _focus,
            style: TextStyle(
              color: item.done ? t.textSecondary : t.textPrimary,
              decoration: item.done ? TextDecoration.lineThrough : null,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
        IconButton(
          key: Key('check-delete-${item.text_}'),
          tooltip: 'Hapus item',
          icon: Icon(Icons.close, size: 18, color: t.textSecondary),
          onPressed: () => repo.deleteChecklistItem(item.id),
        ),
      ],
    );
  }
}
