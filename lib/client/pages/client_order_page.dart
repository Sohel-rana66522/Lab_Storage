import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/lab_inputs.dart';
import '../providers/client_cart_provider.dart';
import '../providers/client_session_provider.dart';
import '../providers/order_provider.dart';
import '../repositories/order_repository.dart';
import '../repositories/student_auth_repository.dart';
import '../utils/client_errors.dart';
import '../widgets/client_ui.dart';
import '../widgets/order_summary.dart';

/// Order submission: who is asking, what they are asking for, and a Submit button.
/// Submitting only creates a Pending request; it never changes laboratory stock.
class ClientOrderPage extends ConsumerStatefulWidget {
  const ClientOrderPage({super.key});
  @override
  ConsumerState<ClientOrderPage> createState() => _ClientOrderPageState();
}

class _ClientOrderPageState extends ConsumerState<ClientOrderPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _batch = TextEditingController();
  final _phone = TextEditingController();

  bool _busy = false;
  bool _slow = false;
  String? _error;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    // Pre-fill from the logged-in student's profile (still editable).
    final profile = ref.read(studentProfileProvider).valueOrNull;
    if (profile != null) {
      _name.text = profile.displayName;
      _id.text = profile.studentId ?? '';
      _batch.text = profile.batch ?? '';
      _phone.text = profile.phone ?? '';
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _name.dispose();
    _id.dispose();
    _batch.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _required(String? v, String message) => (v ?? '').trim().isEmpty ? message : null;

  Future<void> _submit() async {
    if (_busy) return; // guards against a double tap creating two orders
    if (!_form.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    final lines = ref.read(cartProvider);
    if (lines.isEmpty) {
      setState(() => _error = 'Your cart is empty.');
      return;
    }
    if (user == null) {
      setState(() => _error = 'Your session is not ready yet. Please wait a moment and try again.');
      return;
    }

    // Grab everything needed after the await now, while this widget is certainly alive.
    final repo = ref.read(orderRepositoryProvider);
    final cart = ref.read(cartProvider.notifier);
    final router = GoRouter.of(context);

    setState(() {
      _busy = true;
      _slow = false;
      _error = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _busy) setState(() => _slow = true);
    });

    try {
      final order = await repo.submit(
        actor: user,
        clientName: _name.text,
        clientId: _id.text,
        clientBatch: _batch.text,
        clientPhone: _phone.text,
        lines: lines,
      );
      router.go('/order-success/${order.id}');
      cart.clear(); // only after the order is safely stored
    } catch (e) {
      if (mounted) setState(() => _error = clientErrorMessage(e));
    } finally {
      _slowTimer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _slow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(cartEntriesProvider);

    return PageContainer(
      maxWidth: 760,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Row(children: [
          SquareIconButton(
              icon: Icons.arrow_back, tooltip: 'Back to cart', onTap: () => context.go('/cart')),
          const SizedBox(width: 8),
          Text('Order Request', style: AppText.headlineSm),
        ]),
        const SizedBox(height: 12),
        AsyncBody<List<CartEntry>>(
          value: entries,
          onRetry: () => ref.invalidate(chemicalsProvider),
          data: (list) {
            if (list.isEmpty && !_busy) {
              return EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                message: 'Add chemicals to your cart before placing an order.',
                actionLabel: 'Browse Folders',
                onAction: () => context.go('/'),
              );
            }
            return _body(list);
          },
        ),
      ]),
    );
  }

  Widget _body(List<CartEntry> list) {
    final issues = list.where((e) => e.error != null).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDeco.card(),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Client Information', style: AppText.titleMd),
            ]),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Student/Client Name',
              controller: _name,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(OrderRepository.maxNameLength)],
              validator: (v) => _required(v, 'Enter the student/client name'),
            ),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Student/Client ID',
              controller: _id,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(OrderRepository.maxIdLength)],
              validator: (v) => _required(v, 'Enter the student/client ID'),
            ),
            const SizedBox(height: 12),
            LabTextField(
              label: 'Student Batch',
              controller: _batch,
              required: true,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              inputFormatters: [LengthLimitingTextInputFormatter(OrderRepository.maxBatchLength)],
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
          ]),
        ),
      ),
      const SizedBox(height: 12),
      OrderSummary(entries: list),
      const SizedBox(height: 12),
      if (issues.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Some items need attention (for example, the available stock changed). '
                  'Go back to your cart to fix them.',
                  style: AppText.bodyMd.copyWith(color: AppColors.onErrorContainer)),
            ),
          ]),
        ),
      if (_error != null) ...[
        if (issues.isNotEmpty) const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_error!,
                  style: AppText.bodyMd.copyWith(color: AppColors.onErrorContainer)),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: (_busy || issues.isNotEmpty) ? null : _submit,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send_outlined, size: 18),
        label: Text(_busy ? 'Submitting…' : 'Submit Order'),
      ),
      if (_slow) ...[
        const SizedBox(height: 8),
        Text('Still working — please check your internet connection and do not submit twice.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
      const SizedBox(height: 8),
      Text(
          'Submitting sends a request to the laboratory. No chemicals are issued until laboratory staff process it.',
          textAlign: TextAlign.center,
          style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
    ]);
  }
}
