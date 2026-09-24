import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../models/category_model.dart';
import '../../models/chemical_model.dart';
import '../../providers/category_provider.dart';
import '../../providers/chemical_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/common_states.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageContainer(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
            controller: _c,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search chemicals, formulas, folders, students...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _c.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_c.clear)),
            ),
          ),
          const SizedBox(height: 12),
          if (_c.text.trim().isEmpty)
            const EmptyState(
                icon: Icons.manage_search,
                title: 'Search the archive',
                message: 'Find a chemical by name, formula or CAS, a folder, or a student by name or ID.')
          else
            SearchResultsView(query: _c.text),
        ]),
      );
}

/// Global search: folders, chemicals (name / formula / CAS / category) and, for staff,
/// student names and IDs from the usage ledger.
class SearchResultsView extends ConsumerStatefulWidget {
  const SearchResultsView({super.key, required this.query});
  final String query;

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  Timer? _timer;
  late String _debounced = widget.query.trim().toLowerCase();

  @override
  void didUpdateWidget(covariant SearchResultsView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _debounced = widget.query.trim().toLowerCase());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _heading(String s) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(s.toUpperCase(),
            style: AppText.monoSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
      );

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim().toLowerCase();
    final cats = ref.watch(categoriesProvider);
    final chems = ref.watch(chemicalsProvider);

    if (cats.isLoading || chems.isLoading) return const LoadingView();
    if (chems.hasError) return ErrorView(message: friendlyError(chems.error!));

    final catList = cats.valueOrNull ?? const <CategoryModel>[];
    final catName = {for (final c in catList) c.id: c.name};
    final folders = catList.where((c) => c.name.toLowerCase().contains(q)).toList();
    final matches = (chems.valueOrNull ?? const <ChemicalModel>[]).where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.formula.toLowerCase().contains(q) ||
          (c.casNumber ?? '').toLowerCase().contains(q) ||
          (catName[c.categoryId] ?? '').toLowerCase().contains(q);
    }).toList();

    final students = ref.watch(studentSearchProvider(_debounced));

    final nothing = folders.isEmpty && matches.isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (folders.isNotEmpty) ...[
        _heading('Folders'),
        for (final f in folders)
          _ResultTile(
            icon: Icons.folder,
            title: f.name,
            subtitle: 'Folder',
            onTap: () => context.go('/folders/${f.id}'),
          ),
      ],
      if (matches.isNotEmpty) ...[
        _heading('Chemicals'),
        for (final c in matches)
          _ResultTile(
            icon: Icons.description_outlined,
            title: c.name,
            subtitle: [
              if (c.formula.isNotEmpty) Fmt.formula(c.formula),
              catName[c.categoryId] ?? 'Uncategorised',
              'Current: ${Fmt.withUnit(c.currentStock, c.unit)}',
            ].join(' • '),
            warn: c.isLow,
            onTap: () => context.push('/chemicals/${c.id}'),
          ),
      ],
      students.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
        error: (e, _) => const SizedBox.shrink(),
        data: (hits) {
          if (hits.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _heading('Student usage'),
            for (final t in hits)
              _ResultTile(
                icon: Icons.school_outlined,
                title: '${t.studentName ?? 'Student'}${(t.studentId ?? '').isEmpty ? '' : ' (${t.studentId})'}',
                subtitle:
                    'Used ${Fmt.withUnit(t.quantity, t.unit)} ${t.chemicalName} • ${Fmt.date(t.date)}',
                onTap: () => context.push('/chemicals/${t.chemicalId}'),
              ),
          ]);
        },
      ),
      if (nothing && !(students.valueOrNull?.isNotEmpty ?? false) && !students.isLoading)
        EmptyState(icon: Icons.search_off, title: 'No results', message: 'Nothing matches "${widget.query.trim()}".'),
    ]);
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile(
      {required this.icon, required this.title, required this.subtitle, required this.onTap, this.warn = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Ink(
              decoration: AppDeco.card(),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(icon, color: warn ? AppColors.warnFg : AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: AppText.titleSm),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.monoSm.copyWith(color: AppColors.onSurfaceVariant)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline),
              ]),
            ),
          ),
        ),
      );
}
