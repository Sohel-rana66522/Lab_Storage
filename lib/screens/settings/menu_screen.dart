import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_states.dart';
import '../../widgets/dialogs/confirm_dialog.dart';
import '../../widgets/lab_inputs.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const LoadingView();
    final name = Fmt.accountName(user);

    Widget tile(IconData icon, String title, {String? subtitle, VoidCallback? onTap, Color? color}) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(children: [
                Icon(icon, color: color ?? AppColors.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: AppText.titleSm.copyWith(color: color)),
                    if (subtitle != null)
                      Text(subtitle, style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ]),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.outline),
              ]),
            ),
          ),
        );

    return PageContainer(
      maxWidth: 640,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Container(
          decoration: AppDeco.card(),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryContainer,
              child: Text(Fmt.initials(name),
                  style: AppText.headlineSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: AppText.titleMd),
                Text(user.email ?? '', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AppDeco.card(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: tile(Icons.person_outline, 'Edit name', onTap: () => _editName(context, ref, name)),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: AppDeco.card(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: tile(Icons.logout, 'Sign out', color: AppColors.error, onTap: () async {
            final ok = await confirmDialog(context,
                title: 'Sign out?', message: 'You will need to sign in again.', confirmLabel: 'Sign out');
            if (ok) {
              try {
                await ref.read(authRepositoryProvider).signOut();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              }
            }
          }),
        ),
      ]),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String currentName) async {
    final nameC = TextEditingController(text: currentName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit name', style: AppText.headlineSm),
        content: SizedBox(
          width: 360,
          child: LabTextField(label: 'Full name', controller: nameC, required: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || nameC.text.trim().isEmpty) return;
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(nameC.text.trim());
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}
