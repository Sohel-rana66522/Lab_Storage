import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_states.dart';
import '../providers/client_cart_provider.dart';
import '../providers/client_session_provider.dart';
import '../utils/client_errors.dart';

/// Cart and order form. The success page is deliberately NOT part of the cart flow.
bool _inCartFlow(String location) => location.startsWith('/cart') || location == '/order';

void _openCart(BuildContext context, String location) {
  if (location.startsWith('/cart')) return;
  if (location == '/order') {
    context.go('/cart');
  } else {
    context.push('/cart');
  }
}

String _subtitleFor(String location) {
  if (location.startsWith('/order-success')) return 'Order Submitted';
  if (location == '/order') return 'Order Request';
  if (location.startsWith('/cart')) return 'My Chemical Cart';
  if (location.startsWith('/folder')) return 'Client Portal • Folder';
  return 'Client Portal • Folders';
}

/// Responsive frame, mirroring the laboratory app's shell: a top bar with a floating cart
/// button on phones, a navigation rail on tablets and an extended sidebar on desktops.
class ClientShell extends ConsumerWidget {
  const ClientShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < Responsive.compactMax;
    final body = _ClientGate(child: child);

    if (compact) {
      final showFab = count > 0 && !_inCartFlow(location);
      return Scaffold(
        backgroundColor: AppColors.surface,
        floatingActionButton: showFab
            ? FloatingActionButton.extended(
                onPressed: () => _openCart(context, location),
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text('View Cart · $count', style: AppText.titleSm.copyWith(color: Colors.white)),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            _Header(location: location, showBrand: true),
            Expanded(child: body),
          ]),
        ),
      );
    }

    final extended = width >= Responsive.expandedMin;
    final selected = _inCartFlow(location) ? 1 : 0;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Row(children: [
          NavigationRail(
            extended: extended,
            backgroundColor: AppColors.surfaceLowest,
            selectedIndex: selected,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            indicatorColor: AppColors.primaryFixed,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            selectedLabelTextStyle: AppText.titleSm.copyWith(color: AppColors.primary),
            unselectedLabelTextStyle: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: InkWell(
                onTap: () => context.go('/'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 36),
                  if (extended) ...[
                    const SizedBox(width: 10),
                    Text('Lab Ledger', style: AppText.titleMd),
                  ],
                ]),
              ),
            ),
            destinations: [
              const NavigationRailDestination(icon: Icon(Icons.folder), label: Text('Folders')),
              NavigationRailDestination(
                icon: count > 0
                    ? Badge(label: Text('$count'), child: const Icon(Icons.shopping_cart_outlined))
                    : const Icon(Icons.shopping_cart_outlined),
                label: const Text('Cart'),
              ),
            ],
            onDestinationSelected: (i) => i == 0 ? context.go('/') : _openCart(context, location),
          ),
          const VerticalDivider(width: 1, color: AppColors.hairline),
          Expanded(
            child: Column(children: [
              _Header(location: location, showBrand: false),
              Expanded(child: body),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.location, required this.showBrand});
  final String location;
  final bool showBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))],
      ),
      child: Row(children: [
        if (showBrand)
          Expanded(
            child: InkWell(
              onTap: () => context.go('/'),
              child: Row(children: [
                SvgPicture.asset('assets/images/lab_ledger_logo.svg', height: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lab Ledger',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                        Text(_subtitleFor(location),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                      ]),
                ),
              ]),
            ),
          )
        else
          Expanded(
            child: Text(_subtitleFor(location),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
          ),
        if (location != '/')
          IconButton(
            tooltip: 'Home',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined, color: AppColors.onSurfaceVariant),
          ),
        IconButton(
          tooltip: 'Cart',
          onPressed: () => _openCart(context, location),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.shopping_cart_outlined, color: AppColors.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}

/// Waits for the visitor's (anonymous) Firebase session before any page reads Firestore,
/// so the pages never flash an empty catalogue while signing in.
class _ClientGate extends ConsumerWidget {
  const _ClientGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(clientSessionProvider);
    final uid = ref.watch(uidProvider);
    return session.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: clientErrorMessage(e),
        onRetry: () => ref.invalidate(clientSessionProvider),
      ),
      data: (_) => uid == null ? const LoadingView() : child,
    );
  }
}
