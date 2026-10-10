import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firebase_providers.dart';
import '../repositories/order_repository.dart';

final orderRepositoryProvider =
    Provider<OrderRepository>((ref) => OrderRepository(ref.watch(firestoreProvider)));
