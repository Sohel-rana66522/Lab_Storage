import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chemical_provider.dart';
import '../transactions/entry_sheet.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

const _dests = <_Dest>[
  _Dest('/folders', 'Folders', Icons.folder),
  _Dest('/recents', 'Recents', Icons.history),
  _Dest('/low-stock', 'Low Stock', Icons.warning_amber_rounded),
  _Dest('/reports', 'Reports', Icons.summarize_outlined),
  _Dest('/menu', 'Menu', Icons.tune),
];

/// Responsive frame: bottom navigation on phones, navigation rail on tablets,
/// extended sidebar on desktop. Every signed-in user sees the same nav — there
/// are no roles to gate it by.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowCount = ref.watch(lowStockProvider).valueOrNull?.length ?? 0;
    final selected = _dests.indexWhere((d) => location.startsWith(d.path));
    final showFab = location == '/folders';

    final fab = showFab
        ? FloatingActionButton.extended(
            onPressed: () => showChemicalPicker(context),
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: const Icon(Icons.add),
            label: Text('Record Entry', style: AppText.titleSm.copyWith(color: Colors.white)),
          )
        : null;

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Responsive.compactMax;

    if (compact) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        floatingActionButton: fab,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _Header(location: location, showBrand: true, lowCount: lowCount),
            Expanded(child: child),
          ]),
        ),
        bottomNavigationBar: _BottomBar(dests: _dests, selected: selected, lowCount: lowCount),
      );
    }

    final extended = width >= Responsive.expandedMin;
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: fab,
      body: SafeArea(
        child: Row(children: [
          NavigationRail(
            extended: extended,
            backgroundColor: AppColors.surfaceLowest,
            selectedIndex: selected < 0 ? null : selected,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            indicatorColor: AppColors.primaryFixed,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: AppText.titleSm.copyWith(color: AppColors.primary),
            unselectedLabelTextStyle: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 36),
                if (extended) ...[
                  const SizedBox(width: 10),
                  Text('Lab Ledger', style: AppText.titleMd),
                ],
              ]),
            ),
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(
                  icon: d.path == '/low-stock' && lowCount > 0
                      ? Badge(label: Text('$lowCount'), child: Icon(d.icon))
                      : Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
            onDestinationSelected: (i) => context.go(_dests[i].path),
          ),
          const VerticalDivider(width: 1, color: AppColors.hairline),
          Expanded(
            child: Column(children: [
              _Header(location: location, showBrand: false, lowCount: lowCount),
              Expanded(child: child),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _subtitleFor(String location) {
  if (location.startsWith('/recents')) return 'Recent Activity';
  if (location.startsWith('/low-stock')) return 'Low Stock';
  if (location.startsWith('/reports')) return 'Reports';
  if (location.startsWith('/menu')) return 'Menu';
  if (location.startsWith('/search')) return 'Search';
  return 'Chemical Records • Folders';
}

class _Header extends ConsumerWidget {
  const _Header({required this.location, required this.showBrand, required this.lowCount});
  final String location;
  final bool showBrand;
  final int lowCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final initials = user == null ? '?' : Fmt.initials(Fmt.accountName(user));
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: Row(children: [
        if (showBrand) ...[
          SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 32),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(showBrand ? 'Lab Ledger' : _subtitleFor(location),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
            if (showBrand)
              Text(_subtitleFor(location),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          ]),
        ),
        IconButton(
            tooltip: 'Search',
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search, color: AppColors.onSurfaceVariant)),
        IconButton(
          tooltip: 'Low stock',
          onPressed: () => context.go('/low-stock'),
          icon: Stack(clipBehavior: Clip.none, children: [
            const Icon(Icons.notifications_none, color: AppColors.onSurfaceVariant),
            if (lowCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5)),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.go('/menu'),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryContainer,
            child: Text(initials,
                style: AppText.monoSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.dests, required this.selected, required this.lowCount});
  final List<_Dest> dests;
  final int selected;
  final int lowCount;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, -1))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (var i = 0; i < dests.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(dests[i].path),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      dests[i].path == '/low-stock' && lowCount > 0
                          ? Badge(
                              label: Text('$lowCount'),
                              child: Icon(dests[i].icon, size: 22, color: i == selected ? AppColors.primary : AppColors.onSurfaceVariant))
                          : Icon(dests[i].icon,
                              size: 22, color: i == selected ? AppColors.primary : AppColors.onSurfaceVariant),
                      const SizedBox(height: 2),
                      Text(dests[i].label,
                          style: (i == selected ? AppText.titleSm : AppText.bodySm).copyWith(
                              color: i == selected ? AppColors.primary : AppColors.onSurfaceVariant,
                              fontSize: 11)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );
}
