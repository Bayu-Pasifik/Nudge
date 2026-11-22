import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';

class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boards = ref.watch(boardsProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Board')),
      body: boards.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dashboard_outlined, size: 48, color: t.textDisabled),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Belum ada board. Buat yang pertama.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => _BoardTile(board: items[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-board'),
        onPressed: () => showBoardDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Board baru'),
      ),
    );
  }
}

class _BoardTile extends ConsumerWidget {
  const _BoardTile({required this.board});
  final Board board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Material(
      color: t.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () {
          ref.read(repositoryProvider).touchBoard(board.id);
          context.push('/board/${board.id}');
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(board.color),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  board.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<String>(
                key: Key('board-menu-${board.title}'),
                onSelected: (v) async {
                  final repo = ref.read(repositoryProvider);
                  if (v == 'rename') {
                    await showBoardDialog(context, ref, board: board);
                  } else if (v == 'archive') {
                    await repo.archiveBoard(board.id);
                  } else if (v == 'delete') {
                    final ok = await confirmDialog(
                      context,
                      title: 'Hapus board?',
                      message:
                          'Board "${board.title}" beserta semua list dan kartunya akan dihapus.',
                      confirmLabel: 'Hapus',
                      destructive: true,
                    );
                    if (ok) await repo.deleteBoard(board.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Ubah')),
                  PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showBoardDialog(
  BuildContext context,
  WidgetRef ref, {
  Board? board,
}) async {
  final controller = TextEditingController(text: board?.title ?? '');
  var color = board?.color ?? labelColors[5].toARGB32();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(board == null ? 'Board baru' : 'Ubah board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('board-title-field'),
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama board'),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in labelColors)
                  GestureDetector(
                    onTap: () => setState(() => color = c.toARGB32()),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == c.toARGB32()
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('save-board'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  final title = controller.text.trim();
  if (result != true || title.isEmpty) return;
  final repo = ref.read(repositoryProvider);
  if (board == null) {
    await repo.createBoard(title, color: color);
  } else {
    await repo.updateBoard(board.id, title: title, color: color);
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('confirm-dialog'),
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.tokens.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}
