import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_states.dart';

/// Shown after a successful submission. It confirms the REQUEST was received; it never
/// claims chemicals have been issued.
class ClientOrderSuccessPage extends StatelessWidget {
  const ClientOrderSuccessPage({super.key, required this.orderId});
  final String orderId;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: orderId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Order ID copied')));
  }

  @override
  Widget build(BuildContext context) => PageContainer(
        maxWidth: 520,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 24, 16, 32), children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppDeco.card(radius: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.okBg, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 36, color: AppColors.okFg),
                ),
              ),
              const SizedBox(height: 16),
              Text('Order Submitted', textAlign: TextAlign.center, style: AppText.headlineMd),
              const SizedBox(height: 8),
              Text('Your chemical request has been submitted successfully.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyLg.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  Text('ORDER ID',
                      style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(
                      child: SelectableText(orderId,
                          style: AppText.monoLg.copyWith(
                              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    IconButton(
                      tooltip: 'Copy order ID',
                      onPressed: () => _copy(context),
                      icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.onSurfaceVariant),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Track the status of this request under My Orders.',
                  textAlign: TextAlign.center, style: AppText.bodyMd),
              const SizedBox(height: 4),
              Text('This is a request only. No chemicals have been issued yet.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/orders'),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View My Orders'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: const Text('Back to Home'),
              ),
            ]),
          ),
        ]),
      );
}
