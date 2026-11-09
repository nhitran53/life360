import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/account_session.dart';
import '../data/auth_repository.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/chunky.dart';

// ---------------------------------------------------------------------------
// SIGN IN — create an account or log in with email, Google or Apple.
// The AuthGate moves on by itself once the sign-in succeeds.
// ---------------------------------------------------------------------------

enum SignInMode { signUp, logIn }

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.initialMode = SignInMode.signUp,
    this.showApple,
  });

  final SignInMode initialMode;

  /// Defaults to showing Sign in with Apple on Apple devices only.
  final bool? showApple;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late SignInMode _mode = widget.initialMode;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  bool get _signUp => _mode == SignInMode.signUp;

  bool get _showApple =>
      widget.showApple ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS));

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AuthRepository auth) action) async {
    final auth = AccountScope.of(context).auth;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(auth);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isCancelled ? null : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitEmail() {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final password = _password.text;
    _run(
      (auth) => _signUp
          ? auth.signUpWithEmail(email, password)
          : auth.signInWithEmail(email, password),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _error = 'Type your email above first');
      return;
    }
    await _run((auth) => auth.sendPasswordReset(email));
    if (!mounted || _error != null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'If $email has an account, a reset link is on its way 📬',
        ),
      ),
    );
  }

  void _switchMode() => setState(() {
    _mode = _signUp ? SignInMode.logIn : SignInMode.signUp;
    _error = null;
    _formKey.currentState?.reset();
  });

  String? _validateEmail(String? value) =>
      looksLikeEmail(value ?? '') ? null : 'Enter a valid email';

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter a password';
    if (_signUp && password.length < passwordMinLength) {
      return 'Use at least $passwordMinLength characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            children: [
              Text(
                _signUp ? 'Create your account' : 'Welcome back 👋',
                style: text.headlineLarge,
              ),
              const SizedBox(height: 6),
              Text(
                _signUp
                    ? 'So your friends can find you and your streaks are saved.'
                    : 'Log in to pick up where you left off.',
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('email-field'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('password-field'),
                      controller: _password,
                      obscureText: _hidePassword,
                      autofillHints: [
                        _signUp
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitEmail(),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            color: AppColors.muted,
                          ),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                  ],
                ),
              ),
              if (!_signUp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('auth-error'),
                  style: text.bodyMedium?.copyWith(color: AppColors.redText),
                ),
              ],
              const SizedBox(height: 20),
              ChunkyButton(
                label: _busy
                    ? 'One sec…'
                    : _signUp
                    ? 'Create account'
                    : 'Log in',
                onPressed: _busy ? null : _submitEmail,
              ),
              const SizedBox(height: 20),
              const _OrDivider(),
              const SizedBox(height: 20),
              if (_showApple) ...[
                ChunkyButton(
                  label: 'Continue with Apple',
                  icon: Icons.apple,
                  color: AppColors.ink,
                  edgeColor: Colors.black,
                  onPressed: _busy
                      ? null
                      : () => _run((a) => a.signInWithApple()),
                ),
                const SizedBox(height: 12),
              ],
              ChunkyButton.secondary(
                label: 'Continue with Google',
                onPressed: _busy
                    ? null
                    : () => _run((a) => a.signInWithGoogle()),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _switchMode,
                  child: Text(
                    _signUp
                        ? 'Already have an account? Log in'
                        : 'New here? Create an account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
