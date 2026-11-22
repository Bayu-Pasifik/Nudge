import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_backend.dart';

/// Null = local-only mode (Supabase not configured). Overridden in `main()`.
final authBackendProvider = Provider<AuthBackend?>((ref) => null);

/// Who is signed in. Null user id with a non-null backend means "show login".
class AuthSession {
  const AuthSession({required this.configured, this.userId, this.email});
  final bool configured;
  final String? userId;
  final String? email;

  bool get signedIn => userId != null;

  /// The app is usable: either local-only, or signed in.
  bool get canUseApp => !configured || signedIn;
}

class AuthSessionNotifier extends Notifier<AuthSession> {
  StreamSubscription<String?>? _sub;

  @override
  AuthSession build() {
    final backend = ref.watch(authBackendProvider);
    if (backend == null) return const AuthSession(configured: false);
    _sub = backend.userChanges().listen((_) {
      state = AuthSession(
        configured: true,
        userId: backend.userId,
        email: backend.email,
      );
    });
    ref.onDispose(() => _sub?.cancel());
    return AuthSession(
      configured: true,
      userId: backend.userId,
      email: backend.email,
    );
  }
}

final authSessionProvider =
    NotifierProvider<AuthSessionNotifier, AuthSession>(AuthSessionNotifier.new);

/// Bridges the provider to go_router's `refreshListenable`.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Ref ref) {
    ref.listen(authSessionProvider, (_, _) => notifyListeners());
  }
}

final authRefreshProvider = Provider<AuthRefresh>((ref) {
  final r = AuthRefresh(ref);
  ref.onDispose(r.dispose);
  return r;
});
