import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import 'list_column.dart';

const _wideBreakpoint = 768.0;
const _listWidth = 300.0;

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.boardId});
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(boardId));
    final lists = ref.watch(listsProvider(boardId));
    final cards = ref.watch(cardsProvider(boardId));
    final checklist = ref.watch(boardChecklistProvider(boardId));

    final cardsByList = <String, List<TodoCard>>{};
    for (final c in cards.value ?? const <TodoCard>[]) {
      (cardsByList[c.listId] ??= []).add(c);
    }
    final checklistByCard = <String, List<ChecklistItem>>{};
    for (final i in checklist.value ?? const <ChecklistItem>[]) {
      (checklistByCard[i.cardId] ??= []).add(i);
    }

    return Scaffold(
      appBar: AppBar(title: Text(board.value?.title ?? '')),
      body: lists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (items) {
          final columns = <Widget>[
            for (final l in items)
              ListColumn(
                key: ValueKey(l.id),
                list: l,
                cards: cardsByList[l.id] ?? const [],
                checklistByCard: checklistByCard,
              ),
            _AddListColumn(boardId: boardId, isEmpty: items.isEmpty),
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              if (wide) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: columns.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (_, i) => SizedBox(
                    width: _listWidth,
                    child: columns[i],
                  ),
                );
              }
              return _Pager(columns: columns);
            },
          );
        },
      ),
    );
  }
}

/// Phone layout: one list per page with a peek of the next. Stateful so the
/// controller (and current page) survive rebuilds.
class _Pager extends StatefulWidget {
  const _Pager({required this.columns});
  final List<Widget> columns;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  final _controller = PageController(viewportFraction: 0.88);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      padEnds: false,
      itemCount: widget.columns.length,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.fromLTRB(
          i == 0 ? AppSpacing.lg : AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.lg,
        ),
        child: widget.columns[i],
      ),
    );
  }
}

class _AddListColumn extends ConsumerWidget {
  const _AddListColumn({required this.boardId, required this.isEmpty});
  final String boardId;
  final bool isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: t.bgList.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            key: const Key('add-list'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () async {
              final name = await promptText(
                context,
                title: 'List baru',
                label: 'Nama list',
              );
              if (name != null) {
                await ref.read(repositoryProvider).createList(boardId, name);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.add, color: t.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isEmpty ? 'Tambah list pertama' : 'Tambah list',
                    style: TextStyle(color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
