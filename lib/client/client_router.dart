import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/client_cart_page.dart';
import 'pages/client_folder_page.dart';
import 'pages/client_home_page.dart';
import 'pages/client_order_page.dart';
import 'pages/client_order_success_page.dart';
import 'pages/client_shell.dart';
import '../widgets/common_states.dart';

/// Routes of the client portal. There is deliberately no login route and no route to any
/// laboratory screen: this app cannot navigate to the admin side at all.
///
///   /                          home (folders)
///   /folder/:categoryId        chemicals in a folder
///   /cart                      cart
///   /order                     order submission
///   /order-success/:orderId    confirmation
final clientRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.travel_explore,
          title: 'Page not found',
          message: 'That page does not exist in the client portal.',
          actionLabel: 'Back to Home',
          onAction: () => context.go('/'),
        ),
      ),
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ClientShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const ClientHomePage()),
          GoRoute(
            path: '/folder/:categoryId',
            builder: (_, s) => ClientFolderPage(categoryId: s.pathParameters['categoryId']!),
          ),
          GoRoute(path: '/cart', builder: (_, __) => const ClientCartPage()),
          GoRoute(path: '/order', builder: (_, __) => const ClientOrderPage()),
          // A sibling of /order (not a child) so the order form is not left underneath it.
          GoRoute(
            path: '/order-success/:orderId',
            builder: (_, s) => ClientOrderSuccessPage(orderId: s.pathParameters['orderId']!),
          ),
        ],
      ),
    ],
  );
});
