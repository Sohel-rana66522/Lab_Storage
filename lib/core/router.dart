import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/chemicals/chemical_detail_screen.dart';
import '../screens/chemicals/chemical_form_screen.dart';
import '../screens/chemicals/low_stock_screen.dart';
import '../screens/folders/folder_screen.dart';
import '../screens/home/app_shell.dart';
import '../screens/home/folders_screen.dart';
import '../screens/home/search_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/menu_screen.dart';
import '../screens/transactions/recents_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/folders',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) return loc == '/splash' ? null : '/splash';
      final signedIn = auth.valueOrNull != null;
      if (!signedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return '/folders';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/folders',
            builder: (_, __) => const FoldersScreen(),
            routes: [
              GoRoute(
                path: ':categoryId',
                builder: (_, s) => FolderScreen(categoryId: s.pathParameters['categoryId']!),
              ),
            ],
          ),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/recents', builder: (_, __) => const RecentsScreen()),
          GoRoute(path: '/low-stock', builder: (_, __) => const LowStockScreen()),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/menu', builder: (_, __) => const MenuScreen()),
        ],
      ),
      // Order matters: '/chemicals/new' must come before '/chemicals/:id'.
      GoRoute(
        path: '/chemicals/new',
        builder: (_, s) => ChemicalFormScreen(categoryId: s.uri.queryParameters['category']),
      ),
      GoRoute(
        path: '/chemicals/:id',
        builder: (_, s) => ChemicalDetailScreen(chemicalId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, s) => ChemicalFormScreen(chemicalId: s.pathParameters['id']),
          ),
        ],
      ),
    ],
  );
});
