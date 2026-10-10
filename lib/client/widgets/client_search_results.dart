import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../widgets/common_states.dart';
import 'client_chemical_card.dart';

const _subscripts = {
  '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4',
  '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9',
};

/// Lower-cases and turns subscript digits back into plain ones, so "H2SO4" finds
/// "H₂SO₄" and the other way round.
String normalizeForSearch(String s) {
  var out = s.toLowerCase();
  _subscripts.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

/// Name / formula search across every folder. It filters the live chemical list the app
/// already holds, the same approach as the laboratory app, so there is no search backend.
class ClientSearchResults extends ConsumerWidget {
  const ClientSearchResults({super.key, required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = normalizeForSearch(query.trim());
    final cats = ref.watch(categoriesProvider);
    final chems = ref.watch(chemicalsProvider);

    if (cats.isLoading || chems.isLoading) return const LoadingView();
    if (chems.hasError) {
      return ErrorView(
          message: friendlyError(chems.error!), onRetry: () => ref.invalidate(chemicalsProvider));
    }

    final catName = {
      for (final c in cats.valueOrNull ?? const <CategoryModel>[]) c.id: c.name,
    };
    final matches = (chems.valueOrNull ?? const <ChemicalModel>[])
        .where((c) =>
            normalizeForSearch(c.name).contains(q) || normalizeForSearch(c.formula).contains(q))
        .toList();

    if (matches.isEmpty) {
      return EmptyState(
          icon: Icons.search_off,
          title: 'No results',
          message: 'No chemical matches "${query.trim()}". Try a name or a formula such as HCl.');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text('CHEMICALS · ${matches.length}',
            style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
      ),
      for (final c in matches)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClientChemicalCard(chemical: c, categoryName: catName[c.categoryId]),
        ),
    ]);
  }
}
