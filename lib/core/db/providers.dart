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
