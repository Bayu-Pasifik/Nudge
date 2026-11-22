import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';

class CardDragData {
  const CardDragData(this.cardId);
  final String cardId;
}

class ListDragData {
  const ListDragData(this.listId);
  final String listId;
}

/// True while a card or list is being dragged. Used to reveal the edge zones
/// that scroll the board sideways.
class DraggingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final draggingProvider =
    NotifierProvider<DraggingNotifier, bool>(DraggingNotifier.new);

/// Thin horizontal line shown where a dragged card will land.
class InsertionLine extends StatelessWidget {
  const InsertionLine({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: active ? 4 : 0,
      margin: EdgeInsets.symmetric(vertical: active ? 2 : 0),
      decoration: BoxDecoration(
        color: context.tokens.accent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// While something is dragged, hovering over this strip steps the board one
/// page/column in [direction] (-1 left, +1 right) every ~600 ms.
class EdgeScrollZone extends StatefulWidget {
  const EdgeScrollZone({
    super.key,
    required this.direction,
    required this.onStep,
  });

  final int direction;
  final void Function(int direction) onStep;

  @override
  State<EdgeScrollZone> createState() => _EdgeScrollZoneState();
}

class _EdgeScrollZoneState extends State<EdgeScrollZone> {
  Timer? _timer;
  bool _hover = false;

  void _start() {
    _timer?.cancel();
    setState(() => _hover = true);
    widget.onStep(widget.direction);
    _timer = Timer.periodic(
      const Duration(milliseconds: 600),
      (_) => widget.onStep(widget.direction),
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _hover = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (_) {
        _start();
        return false; // never consumes the drop; only drives scrolling
      },
      onLeave: (_) => _stop(),
      builder: (context, _, _) => Container(
        width: 40,
        color: _hover ? t.accent.withValues(alpha: 0.18) : Colors.transparent,
        alignment: Alignment.center,
        child: Icon(
          widget.direction < 0 ? Icons.chevron_left : Icons.chevron_right,
          color: t.accent,
        ),
      ),
    );
  }
}
