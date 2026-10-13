import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import 'pages/client_auth_pages.dart';
import 'pages/client_cart_page.dart';
import 'pages/client_folder_page.dart';
import 'pages/client_home_page.dart';
import 'pages/client_my_orders_page.dart';
import 'pages/client_order_page.dart';
import 'pages/client_profile_page.dart';
import 'pages/client_order_success_page.dart';
import 'pages/client_shell.dart';
import 'providers/client_session_provider.dart';
import '../widgets/common_states.dart';

/// Routes of the client portal. Students must log in (or sign up) first; there is deliberately
/// no route to any laboratory screen: this app cannot navigate to the admin side at all.
///
///   /login                     student login (name + student ID)
///   /signup                    student sign-up (name, student ID, batch, phone)
///   /                          home (folders)
///   /folder/:categoryId        chemicals in a folder
///   /cart                      cart
///   /order                     order submission
///   /order-success/:orderId    confirmation
///   /orders                    my orders and their status
///   /profile                   student profile (edit name, batch, phone)
final clientRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.listen(studentAuthBusyProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) return loc == '/splash' ? null : '/splash';

      // While the login / sign-up form is still working, a new session does not count yet.
      final loggedIn =
          ref.read(isStudentSignedInProvider) && !ref.read(studentAuthBusyProvider);
      final onAuthPage = loc == '/login' || loc == '/signup';

      if (!loggedIn) return onAuthPage ? null : '/login';
      if (onAuthPage || loc == '/splash') return '/';
      return null;
    },
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
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/login', builder: (_, __) => const ClientLoginPage()),
      GoRoute(path: '/signup', builder: (_, __) => const ClientSignupPage()),
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
          GoRoute(path: '/orders', builder: (_, __) => const ClientMyOrdersPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ClientProfilePage()),
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
