import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_backend.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/theme/tokens.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail() {
    final e = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final info = await action();
      if (mounted) setState(() => _info = info);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final backend = ref.read(authBackendProvider)!;
    final emailErr = _validateEmail();
    if (emailErr != null) return setState(() => _error = emailErr);
    final pass = _password.text;
    if (pass.length < 6) {
      return setState(() => _error = 'Password minimal 6 karakter.');
    }
    final email = _email.text.trim();
    await _run(() async {
      if (_signUp) {
        final ready = await backend.signUp(email, pass);
        return ready
            ? null
            : 'Akun dibuat. Cek email kamu untuk konfirmasi, lalu masuk.';
      }
      await backend.signInWithPassword(email, pass);
      return null;
    });
  }

  Future<void> _magic() async {
    final err = _validateEmail();
    if (err != null) return setState(() => _error = err);
    final email = _email.text.trim();
    await _run(() async {
      await ref.read(authBackendProvider)!.sendMagicLink(email);
      return 'Tautan masuk dikirim ke $email.';
    });
  }

  Future<void> _forgot() async {
    final err = _validateEmail();
    if (err != null) return setState(() => _error = err);
    final email = _email.text.trim();
    await _run(() async {
      await ref.read(authBackendProvider)!.resetPassword(email);
      return 'Tautan atur ulang password dikirim ke $email.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/logo/nudge_mark.png',
                      key: const Key('auth-logo'),
                      width: 72,
                      height: 72,
                      semanticLabel: 'Logo Nudge',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Nudge',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Todo yang menempel dan terus mengingatkan.',
                    style: TextStyle(color: t.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Masuk', key: Key('mode-login')),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Daftar', key: Key('mode-signup')),
                      ),
                    ],
                    selected: {_signUp},
                    onSelectionChanged: (s) => setState(() {
                      _signUp = s.first;
                      _error = null;
                      _info = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('auth-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('auth-password'),
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: [
                      _signUp
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Tampilkan' : 'Sembunyikan',
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: t.danger, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            key: const Key('auth-error'),
                            style: TextStyle(color: t.danger),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _info!,
                      key: const Key('auth-info'),
                      style: TextStyle(color: t.success),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const Key('auth-submit'),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_signUp ? 'Buat akun' : 'Masuk'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    key: const Key('auth-magic'),
                    onPressed: _busy ? null : _magic,
                    child: const Text('Kirim tautan masuk ke email'),
                  ),
                  if (!_signUp)
                    TextButton(
                      key: const Key('auth-forgot'),
                      onPressed: _busy ? null : _forgot,
                      child: const Text('Lupa password?'),
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
