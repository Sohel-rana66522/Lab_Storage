import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/common_states.dart';
import '../../widgets/lab_inputs.dart';
import '../providers/client_session_provider.dart';
import '../repositories/student_auth_repository.dart';
import '../utils/client_errors.dart';

/// The logged-in student's profile. Name, batch and phone can be edited; the Student ID is
/// shown but locked because the login account is built from it.
class ClientProfilePage extends ConsumerWidget {
  const ClientProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider).valueOrNull;
    if (profile == null) return const LoadingView();
    return PageContainer(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [_ProfileForm(profile: profile)],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});
  final UserModel profile;
  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.displayName);
  late final _id = TextEditingController(text: widget.profile.studentId ?? '');
  late final _batch = TextEditingController(text: widget.profile.batch ?? '');
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
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

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final repo = ref.read(studentAuthRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.updateProfile(name: _name.text, batch: _batch.text, phone: _phone.text);
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (mounted) setState(() => _error = clientErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDeco.card(),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('My Profile', style: AppText.titleMd),
          ]),
          const SizedBox(height: 12),
          LabTextField(
            label: 'Student Name',
            controller: _name,
            required: true,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(StudentAuthRepository.maxNameLength)],
            validator: StudentAuthRepository.validateName,
          ),
          const SizedBox(height: 12),
          LabTextField(
            label: 'Student ID',
            controller: _id,
            enabled: false,
            helper: 'Your Student ID is your login and cannot be changed.',
          ),
          const SizedBox(height: 12),
          LabTextField(
            label: 'Student Batch',
            controller: _batch,
            required: true,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(StudentAuthRepository.maxBatchLength)],
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
            onSubmitted: (_) => _save(),
            validator: StudentAuthRepository.validatePhone,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppText.bodyMd.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ]),
      ),
    );
  }
}
