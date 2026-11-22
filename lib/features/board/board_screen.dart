import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/tokens.dart';
import 'drag.dart';
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
        data: (items) => _BoardBody(
          columns: [
            for (var i = 0; i < items.length; i++)
              _ListDropTarget(
                key: ValueKey('target-${items[i].id}'),
                index: i,
                child: ListColumn(
                  key: ValueKey(items[i].id),
                  list: items[i],
                  cards: cardsByList[items[i].id] ?? const [],
                  checklistByCard: checklistByCard,
                ),
              ),
            _AddListColumn(boardId: boardId, isEmpty: items.isEmpty),
          ],
        ),
      ),
    );
  }
}

/// Lays the columns out (paged on phones, side by side on wide screens) and
/// owns the scroll controllers so dragging near an edge can scroll the board.
class _BoardBody extends ConsumerStatefulWidget {
  const _BoardBody({required this.columns});
  final List<Widget> columns;

  @override
  ConsumerState<_BoardBody> createState() => _BoardBodyState();
}

class _BoardBodyState extends ConsumerState<_BoardBody> {
  final _page = PageController(viewportFraction: 0.88);
  final _scroll = ScrollController();

  @override
  void dispose() {
    _page.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _step(int dir, bool wide) {
    if (wide) {
      if (!_scroll.hasClients) return;
      final to = (_scroll.offset + dir * (_listWidth + AppSpacing.md))
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      if (!_page.hasClients) return;
      final next = (_page.page!.round() + dir).clamp(0, widget.columns.length - 1);
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dragging = ref.watch(draggingProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final columns = widget.columns;
        final Widget body = wide
            ? ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: columns.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) =>
                    SizedBox(width: _listWidth, child: columns[i]),
              )
            : PageView.builder(
                controller: _page,
                padEnds: false,
                itemCount: columns.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    i == 0 ? AppSpacing.lg : AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.lg,
                  ),
                  child: columns[i],
                ),
              );
        return Stack(
          children: [
            Positioned.fill(child: body),
            if (dragging) ...[
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: EdgeScrollZone(
                  key: const Key('edge-left'),
                  direction: -1,
                  onStep: (d) => _step(d, wide),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: EdgeScrollZone(
                  key: const Key('edge-right'),
                  direction: 1,
                  onStep: (d) => _step(d, wide),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Dropping a list header here moves the dragged list to this column's index.
class _ListDropTarget extends ConsumerWidget {
  const _ListDropTarget({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return DragTarget<ListDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) =>
          ref.read(repositoryProvider).moveList(d.data.listId, index),
      builder: (context, candidates, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: candidates.isEmpty
              ? null
              : Border.all(color: t.accent, width: 2),
        ),
        child: child,
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
