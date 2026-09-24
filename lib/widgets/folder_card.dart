import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../models/category_model.dart';
import '../providers/chemical_provider.dart';
import 'common_states.dart';

/// A folder in the archive. Grid variant follows the Stitch "Classified Storage Folders" card.
class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.category, required this.stats, required this.onTap});
  final CategoryModel category;
  final FolderStats stats;
  final VoidCallback onTap;

  static Widget badge(FolderStats s) {
    if (s.low > 0) {
      return Pill('${s.low} Low',
          bg: AppColors.errorContainer, fg: AppColors.onErrorContainer, icon: Icons.circle);
    }
    return Pill(s.count == 0 ? 'Empty' : '${s.count} Items',
        bg: AppColors.surfaceHigh, fg: AppColors.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    final peek = stats.formulas.isEmpty ? '—' : stats.formulas.join(' • ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: AppDeco.card(),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                child: Icon(stats.count == 0 ? Icons.folder_open : Icons.folder,
                    size: 20, color: AppColors.primary),
              ),
              badge(stats),
            ]),
            const SizedBox(height: 8),
            Text(category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700)),
            Text('${stats.count} Chemicals logged',
                style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FORMULA PEEK',
                    style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
                Text(peek,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoMd.copyWith(color: AppColors.primary)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Compact list-view row for a folder.
class FolderListTile extends StatelessWidget {
  const FolderListTile({super.key, required this.category, required this.stats, required this.onTap});
  final CategoryModel category;
  final FolderStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            decoration: AppDeco.card(),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(category.name, style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    stats.formulas.isEmpty
                        ? '${stats.count} Chemicals logged'
                        : '${stats.count} Chemicals • ${stats.formulas.join(' • ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              FolderCard.badge(stats),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ]),
          ),
        ),
      );
}
