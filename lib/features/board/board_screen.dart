import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/db/providers.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.boardId});
  final String boardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider(boardId));
    return Scaffold(
      appBar: AppBar(title: Text(board.value?.title ?? '')),
      body: const SizedBox.shrink(),
    );
  }
}
