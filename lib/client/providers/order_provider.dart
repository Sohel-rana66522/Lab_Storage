import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_providers.dart';
import '../../providers/auth_provider.dart';
import '../models/order_model.dart';
import '../repositories/order_repository.dart';

final orderRepositoryProvider =
    Provider<OrderRepository>((ref) => OrderRepository(ref.watch(firestoreProvider)));

/// This visitor's own orders with their current status, live: when the laboratory approves
/// or rejects an order the change shows up here without a refresh.
final myOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <OrderModel>[]);
  return ref.watch(orderRepositoryProvider).watchMine(uid);
});
