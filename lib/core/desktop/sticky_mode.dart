import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/providers.dart';
import '../db/repository.dart';

/// Applies the OS-window side of sticky mode (always on top, small, borderless).
/// Injected so tests need no real window.
abstract class WindowController {
  Future<void> enterSticky();
  Future<void> exitSticky();
  Future<void> show();
  Future<void> raiseTemporarily();
}

class NoopWindowController implements WindowController {
  @override
  Future<void> enterSticky() async {}
  @override
  Future<void> exitSticky() async {}
  @override
  Future<void> show() async {}
  @override
  Future<void> raiseTemporarily() async {}
}

final windowControllerProvider =
    Provider<WindowController>((ref) => NoopWindowController());

/// True while the desktop app is shown as a small always-on-top sticky window.
class StickyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> set(bool on) async {
    if (state == on) return;
    state = on;
    final w = ref.read(windowControllerProvider);
    if (on) {
      await w.enterSticky();
    } else {
      await w.exitSticky();
    }
  }

  Future<void> toggle() => set(!state);
}

final stickyModeProvider =
    NotifierProvider<StickyModeNotifier, bool>(StickyModeNotifier.new);

final stickyNotesProvider = StreamProvider.autoDispose<List<StickyInfo>>(
  (ref) => ref.watch(repositoryProvider).watchPinnedStickies(),
);
