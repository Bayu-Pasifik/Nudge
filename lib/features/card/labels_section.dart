import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import '../boards/boards_screen.dart' show confirmDialog;

class LabelEdit {
  const LabelEdit({this.name, this.color, this.delete = false});
  final String? name;
  final int? color;
  final bool delete;
}

/// Create/rename/recolor/delete dialog. Returns null if cancelled.
Future<LabelEdit?> showLabelDialog(BuildContext context, {Label? label}) async {
  final controller = TextEditingController(text: label?.name ?? '');
  var color = label?.color ?? labelColors[3].toARGB32();
  final result = await showDialog<LabelEdit>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(label == null ? 'Label baru' : 'Ubah label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('label-name-field'),
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama label'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < labelColors.length; i++)
                  GestureDetector(
                    key: Key('label-color-$i'),
                    onTap: () => setState(() => color = labelColors[i].toARGB32()),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: labelColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == labelColors[i].toARGB32()
                              ? Theme.of(ctx).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (label != null)
            TextButton(
              key: const Key('label-delete'),
              onPressed: () => Navigator.pop(ctx, const LabelEdit(delete: true)),
              child: Text(
                'Hapus',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('label-save'),
            onPressed: () => Navigator.pop(
              ctx,
              LabelEdit(name: controller.text.trim(), color: color),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  return result;
}

/// Toggle board labels on a card; the pencil on a label edits or deletes it.
class LabelsSection extends ConsumerWidget {
  const LabelsSection({super.key, required this.card});
  final TodoCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final labels = ref.watch(boardLabelsProvider(card.boardId)).value ?? const [];
    final attached = {
      for (final l in ref.watch(labelsByCardProvider)[card.id] ?? const <Label>[])
        l.id,
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final l in labels)
          InputChip(
            key: Key('label-${l.name}'),
            avatar: CircleAvatar(backgroundColor: Color(l.color), radius: 6),
            label: Text(l.name),
            selected: attached.contains(l.id),
            onSelected: (v) => repo.setCardLabel(card.id, l.id, v),
            // The trailing pencil edits or deletes the label.
            deleteIcon: const Icon(Icons.edit, size: 16, key: Key('label-edit')),
            deleteButtonTooltipMessage: 'Ubah label',
            onDeleted: () async {
              final edit = await showLabelDialog(context, label: l);
              if (edit == null) return;
              if (edit.delete) {
                if (!context.mounted) return;
                final ok = await confirmDialog(
                  context,
                  title: 'Hapus label?',
                  message: 'Label "${l.name}" dilepas dari semua kartu.',
                  confirmLabel: 'Hapus',
                  destructive: true,
                );
                if (ok) await repo.deleteLabel(l.id);
              } else if ((edit.name ?? '').isNotEmpty) {
                await repo.updateLabel(l.id, name: edit.name, color: edit.color);
              }
            },
          ),
        ActionChip(
          key: const Key('add-label'),
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Label'),
          onPressed: () async {
            final edit = await showLabelDialog(context);
            final name = edit?.name ?? '';
            if (edit == null || edit.delete || name.isEmpty) return;
            final id = await repo.createLabel(card.boardId, name, edit.color!);
            await repo.setCardLabel(card.id, id, true);
          },
        ),
      ],
    );
  }
}
