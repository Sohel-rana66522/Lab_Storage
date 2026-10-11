import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../client/models/order_model.dart';
import '../core/services/firebase_providers.dart';
import '../repositories/order_admin_repository.dart';
import 'auth_provider.dart';

final orderAdminRepositoryProvider =
    Provider<OrderAdminRepository>((ref) => OrderAdminRepository(ref.watch(firestoreProvider)));

/// Every order, newest first, live. Pending orders appear here the moment a client submits.
final ordersProvider = StreamProvider<List<OrderModel>>((ref) {
  if (ref.watch(uidProvider) == null) return Stream.value(const <OrderModel>[]);
  return ref.watch(orderAdminRepositoryProvider).watchAll();
});

final orderProvider = StreamProvider.family<OrderModel?, String>((ref, id) {
  if (ref.watch(uidProvider) == null) return Stream.value(null);
  return ref.watch(orderAdminRepositoryProvider).watchOne(id);
});

/// Number of Pending orders, for the navigation badge.
final pendingOrderCountProvider = Provider<int>((ref) {
  final orders = ref.watch(ordersProvider).valueOrNull ?? const <OrderModel>[];
  return orders.where((o) => o.isPending).length;
});

/// Whether the signed-in user holds the ADMIN role. Only decides whether the Approve /
/// Reject buttons are shown; the security rules and the approval transaction enforce it.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(uidProvider);
  if (uid == null) return false;
  return ref.watch(orderAdminRepositoryProvider).isAdmin(uid);
});
