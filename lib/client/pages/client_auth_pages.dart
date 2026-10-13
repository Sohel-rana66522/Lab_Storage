import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/lab_inputs.dart';
import '../providers/client_session_provider.dart';
import '../repositories/student_auth_repository.dart';
import '../utils/client_errors.dart';

/// Shared frame of the two student auth pages.
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.subtitle, required this.child});
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppDeco.card(radius: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 56)),
                      const SizedBox(height: 12),
                      Text('Lab Ledger',
                          textAlign: TextAlign.center, style: AppText.headlineMd),
                      Text(subtitle,
                          textAlign: TextAlign.center,
                          style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.busy, required this.label, required this.onPressed});
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      );
}

/// Student login: name + student ID.
class ClientLoginPage extends ConsumerStatefulWidget {
  const ClientLoginPage({super.key});
  @override
  ConsumerState<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends ConsumerState<ClientLoginPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final repo = ref.read(studentAuthRepositoryProvider);
    final gate = ref.read(studentAuthBusyProvider.notifier);
    gate.state = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.signIn(name: _name.text, studentId: _id.text);
    } catch (e) {
      if (mounted) setState(() => _error = clientErrorMessage(e));
    } finally {
      gate.state = false; // the router lets a successful login through now
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
        subtitle: 'Student Login',
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LabTextField(
              label: 'Student Name',
              controller: _name,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(StudentAuthRepository.maxNameLength)
              ],
              validator: StudentAuthRepository.validateName,
            ),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Student ID',
              controller: _id,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(StudentAuthRepository.maxIdLength)
              ],
              onSubmitted: (_) => _submit(),
              validator: StudentAuthRepository.validateId,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.bodyMd.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            _SubmitButton(busy: _busy, label: 'Log in', onPressed: _submit),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _busy ? null : () => context.go('/signup'),
                child: const Text("New student? Sign up"),
              ),
            ),
          ]),
        ),
      );
}

/// Student sign-up: name, student ID and batch. Creates the account and its `users` profile.
class ClientSignupPage extends ConsumerStatefulWidget {
  const ClientSignupPage({super.key});
  @override
  ConsumerState<ClientSignupPage> createState() => _ClientSignupPageState();
}

class _ClientSignupPageState extends ConsumerState<ClientSignupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _batch = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _batch.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final repo = ref.read(studentAuthRepositoryProvider);
    final gate = ref.read(studentAuthBusyProvider.notifier);
    gate.state = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.signUp(
          name: _name.text, studentId: _id.text, batch: _batch.text, phone: _phone.text);
    } catch (e) {
      if (mounted) setState(() => _error = clientErrorMessage(e));
    } finally {
      gate.state = false; // the router lets the new student in now
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
        subtitle: 'Student Sign Up',
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LabTextField(
              label: 'Student Name',
              controller: _name,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(StudentAuthRepository.maxNameLength)
              ],
              validator: StudentAuthRepository.validateName,
            ),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Student ID',
              controller: _id,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(StudentAuthRepository.maxIdLength)
              ],
              validator: StudentAuthRepository.validateId,
            ),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Student Batch',
              controller: _batch,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(StudentAuthRepository.maxBatchLength)
              ],
              validator: StudentAuthRepository.validateBatch,
            ),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Phone Number',
              controller: _phone,
              required: true,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                LengthLimitingTextInputFormatter(StudentAuthRepository.maxPhoneLength),
              ],
              onSubmitted: (_) => _submit(),
              validator: StudentAuthRepository.validatePhone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.bodyMd.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            _SubmitButton(busy: _busy, label: 'Create account', onPressed: _submit),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _busy ? null : () => context.go('/login'),
                child: const Text('Already registered? Log in'),
              ),
            ),
          ]),
        ),
      );
}
