import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import '../widgets/client_chemical_card.dart';
import '../widgets/client_search_results.dart';
import '../widgets/client_ui.dart';

/// Inside one folder: the chemicals it holds, with live availability and Add to cart.
class ClientFolderPage extends ConsumerStatefulWidget {
  const ClientFolderPage({super.key, required this.categoryId});
  final String categoryId;

  @override
  ConsumerState<ClientFolderPage> createState() => _ClientFolderPageState();
}

class _ClientFolderPageState extends ConsumerState<ClientFolderPage> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    final chemsAsync = ref.watch(chemicalsProvider);

    return PageContainer(
      child: AsyncBody<List<CategoryModel>>(
        value: catsAsync,
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (cats) {
          final cat = cats.firstWhereOrNull((c) => c.id == widget.categoryId);
          if (cat == null) {
            return EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Folder not found',
              message: 'It may have been removed.',
              actionLabel: 'Back to folders',
              onAction: () => context.go('/'),
            );
          }
          return AsyncBody<List<ChemicalModel>>(
            value: chemsAsync,
            onRetry: () => ref.invalidate(chemicalsProvider),
            data: (all) => _content(cat, all.where((c) => c.categoryId == cat.id).toList()),
          );
        },
      ),
    );
  }

  Widget _content(CategoryModel cat, List<ChemicalModel> inFolder) {
    final q = normalizeForSearch(_filter.text.trim());
    final shown = inFolder
        .where((c) =>
            q.isEmpty ||
            normalizeForSearch(c.name).contains(q) ||
            normalizeForSearch(c.formula).contains(q))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      // Breadcrumb
      Row(children: [
        SquareIconButton(icon: Icons.arrow_back, tooltip: 'Back to all folders', onTap: () => context.go('/')),
        const SizedBox(width: 8),
        Expanded(
          child: Row(children: [
            Text('Lab Root', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.outline),
            const Icon(Icons.folder_open, size: 15, color: AppColors.primary),
            const SizedBox(width: 4),
            Flexible(
                child: Text(cat.name,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleSm.copyWith(color: AppColors.primary))),
          ]),
        ),
      ]),
      const SizedBox(height: 12),

      // Folder header card (same look as the laboratory app, without staff actions)
      Container(
        decoration: AppDeco.card(),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.primary, AppColors.secondary])),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder_open, size: 26, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat.name, style: AppText.headlineSm),
                  Text(
                      '${(cat.description ?? '').isEmpty ? '' : '${cat.description} • '}'
                      '${inFolder.length} Item${inFolder.length == 1 ? '' : 's'}',
                      style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      Row(children: [
        const Icon(Icons.science_outlined, size: 18, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('Available Chemicals', style: AppText.titleMd),
      ]),
      const SizedBox(height: 8),
      TextField(
        controller: _filter,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Filter by name or formula...',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _filter.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear filter',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(_filter.clear)),
        ),
      ),
      const SizedBox(height: 12),

      if (inFolder.isEmpty)
        const EmptyState(
          icon: Icons.science_outlined,
          title: 'No chemicals in this folder yet.',
          message: 'Check back later or browse another folder.',
        )
      else if (shown.isEmpty)
        const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try a different filter.')
      else ...[
        for (final c in shown)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: ClientChemicalCard(chemical: c)),
        const SizedBox(height: 4),
        Text('Showing ${shown.length} of ${inFolder.length} chemicals',
            style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    ]);
  }
}
