import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'repository.dart';

/// Overridden in `main()` and in tests (in-memory DB).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<Repository>(
  (ref) => Repository(ref.watch(appDatabaseProvider)),
);

final boardsProvider = StreamProvider<List<Board>>(
  (ref) => ref.watch(repositoryProvider).watchBoards(),
);

final boardProvider = StreamProvider.autoDispose.family<Board?, String>(
  (ref, id) => ref.watch(repositoryProvider).watchBoard(id),
);

final listsProvider =
    StreamProvider.autoDispose.family<List<BoardList>, String>(
  (ref, boardId) => ref.watch(repositoryProvider).watchLists(boardId),
);

final cardsProvider = StreamProvider.autoDispose.family<List<TodoCard>, String>(
  (ref, boardId) => ref.watch(repositoryProvider).watchCards(boardId),
);

final cardProvider = StreamProvider.autoDispose.family<TodoCard?, String>(
  (ref, id) => ref.watch(repositoryProvider).watchCard(id),
);

final checklistProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, String>(
  (ref, cardId) => ref.watch(repositoryProvider).watchChecklist(cardId),
);

final boardLabelsProvider =
    StreamProvider.autoDispose.family<List<Label>, String>(
  (ref, boardId) => ref.watch(repositoryProvider).watchLabels(boardId),
);

final allLabelsProvider = StreamProvider.autoDispose<List<Label>>(
  (ref) => ref.watch(repositoryProvider).watchAllLabels(),
);

final allCardLabelsProvider = StreamProvider.autoDispose<List<CardLabel>>(
  (ref) => ref.watch(repositoryProvider).watchAllCardLabels(),
);

/// card id -> its labels, for tiles and filters.
final labelsByCardProvider = Provider.autoDispose<Map<String, List<Label>>>((ref) {
  final labels = {
    for (final l in ref.watch(allLabelsProvider).value ?? const <Label>[]) l.id: l,
  };
  final out = <String, List<Label>>{};
  for (final cl in ref.watch(allCardLabelsProvider).value ?? const <CardLabel>[]) {
    final l = labels[cl.labelId];
    if (l != null) (out[cl.cardId] ??= []).add(l);
  }
  return out;
});

final boardChecklistProvider =
    StreamProvider.autoDispose.family<List<ChecklistItem>, String>(
  (ref, boardId) => ref.watch(repositoryProvider).watchBoardChecklist(boardId),
);
