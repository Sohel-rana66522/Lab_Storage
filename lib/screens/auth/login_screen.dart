import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/lab_inputs.dart';

/// Sign-in only — there's no self-service account creation. Accounts are
/// created for people ahead of time (e.g. directly in the Firebase console).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
      // The router redirects once auth state changes.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first, then tap "Forgot password".');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _info = 'Password reset email sent.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: AppDeco.card(radius: 16),
                child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(child: SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 56)),
                    const SizedBox(height: 12),
                    Text('Lab Ledger', textAlign: TextAlign.center, style: AppText.headlineMd),
                    Text('Chemical Records',
                        textAlign: TextAlign.center,
                        style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    LabTextField(
                      label: 'Email',
                      controller: _email,
                      required: true,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : 'Enter a valid email address',
                    ),
                    const SizedBox(height: 12),
                    LabTextField(
                      label: 'Password',
                      controller: _password,
                      required: true,
                      obscure: true,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: AppText.bodyMd.copyWith(color: AppColors.error)),
                    ],
                    if (_info != null) ...[
                      const SizedBox(height: 12),
                      Text(_info!, style: AppText.bodyMd.copyWith(color: AppColors.tertiary)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _busy ? null : _reset, child: const Text('Forgot password')),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while auth state is still resolving.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 64),
            const SizedBox(height: 16),
            if (!auth.hasError)
              const CircularProgressIndicator(color: AppColors.primaryContainer)
            else ...[
              const Icon(Icons.error_outline, color: AppColors.error, size: 32),
              const SizedBox(height: 8),
              Text(friendlyError(auth.error!), textAlign: TextAlign.center, style: AppText.bodyMd),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out and try again'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
