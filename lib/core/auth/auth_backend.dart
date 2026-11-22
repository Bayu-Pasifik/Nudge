import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config.dart';

/// Narrow auth surface so screens and sync can be tested without Supabase.
abstract class AuthBackend {
  /// Current user id, or null when signed out.
  String? get userId;
  String? get email;

  /// Emits the user id on sign-in and null on sign-out.
  Stream<String?> userChanges();

  Future<void> signInWithPassword(String email, String password);

  /// Returns true if the account is usable immediately, false if the user
  /// must first confirm their email.
  Future<bool> signUp(String email, String password);
  Future<void> sendMagicLink(String email);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

/// A user-facing auth problem, already phrased in Indonesian.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class SupabaseAuthBackend implements AuthBackend {
  SupabaseAuthBackend(this.client);
  final sb.SupabaseClient client;

  sb.GoTrueClient get _auth => client.auth;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<String?> userChanges() =>
      _auth.onAuthStateChange.map((s) => s.session?.user.id);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on sb.AuthException catch (e) {
      throw AuthFailure(_translate(e.message));
    } catch (e) {
      throw const AuthFailure('Tidak bisa terhubung. Periksa koneksi internet.');
    }
  }

  static String _translate(String m) {
    final l = m.toLowerCase();
    if (l.contains('invalid login')) return 'Email atau password salah.';
    if (l.contains('already registered')) return 'Email sudah terdaftar.';
    if (l.contains('password should be')) {
      return 'Password terlalu pendek (minimal 6 karakter).';
    }
    if (l.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek kotak masuk kamu.';
    }
    if (l.contains('rate limit')) return 'Terlalu sering mencoba. Coba lagi nanti.';
    return m;
  }

  @override
  Future<void> signInWithPassword(String email, String password) => _guard(
        () => _auth.signInWithPassword(email: email, password: password),
      );

  @override
  Future<bool> signUp(String email, String password) => _guard(() async {
        final res = await _auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: AppConfig.authRedirect,
        );
        return res.session != null;
      });

  @override
  Future<void> sendMagicLink(String email) => _guard(
        () => _auth.signInWithOtp(
          email: email,
          emailRedirectTo: AppConfig.authRedirect,
        ),
      );

  @override
  Future<void> resetPassword(String email) => _guard(
        () => _auth.resetPasswordForEmail(
          email,
          redirectTo: AppConfig.authRedirect,
        ),
      );

  @override
  Future<void> signOut() => _guard(_auth.signOut);
}

/// In-memory backend for tests.
class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({String? userId, this.requireConfirmation = false})
      : _userId = userId,
        _email = userId == null ? null : 'user@example.com';

  String? _userId;
  String? _email;
  final bool requireConfirmation;
  final _controller = StreamController<String?>.broadcast();
  final Map<String, String> accounts = {'user@example.com': 'secret123'};
  final List<String> magicLinks = [];
  final List<String> resets = [];

  @override
  String? get userId => _userId;
  @override
  String? get email => _email;

  @override
  Stream<String?> userChanges() => _controller.stream;

  void _set(String? id, String? mail) {
    _userId = id;
    _email = mail;
    _controller.add(id);
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    if (accounts[email] != password) {
      throw const AuthFailure('Email atau password salah.');
    }
    _set('user-${email.hashCode}', email);
  }

  @override
  Future<bool> signUp(String email, String password) async {
    if (accounts.containsKey(email)) {
      throw const AuthFailure('Email sudah terdaftar.');
    }
    if (password.length < 6) {
      throw const AuthFailure('Password terlalu pendek (minimal 6 karakter).');
    }
    accounts[email] = password;
    if (requireConfirmation) return false;
    _set('user-${email.hashCode}', email);
    return true;
  }

  @override
  Future<void> sendMagicLink(String email) async => magicLinks.add(email);

  @override
  Future<void> resetPassword(String email) async => resets.add(email);

  @override
  Future<void> signOut() async => _set(null, null);
}
