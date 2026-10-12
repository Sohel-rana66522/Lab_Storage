import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../client/models/order_model.dart';
import '../core/utils/formatters.dart';
import '../models/chemical_model.dart';
import 'chemical_provider.dart';
import 'order_admin_provider.dart';

enum NotificationKind { order, lowStock }

/// A notification derived from live data (orders and chemical stock). Nothing is stored:
/// each one disappears on its own once it is older than [AppNotification.lifetime].
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    required this.route,
    this.urgent = false,
  });

  /// How long a notification stays visible.
  static const lifetime = Duration(days: 7);

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime time;

  /// Where tapping the notification goes.
  final String route;
  final bool urgent;
}

/// Number shown on the bell badge: pending orders plus low / depleted chemicals.
/// Approved or rejected orders stay in the list but never light the badge.
final notificationBadgeCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .where((n) => n.kind == NotificationKind.lowStock || n.urgent)
      .length;
});

/// New client orders and low / depleted chemicals from the last 7 days, newest first.
/// Re-evaluated every hour so old notifications drop off even if the app stays open.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final timer = Timer.periodic(const Duration(hours: 1), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);

  final cutoff = DateTime.now().subtract(AppNotification.lifetime);
  final out = <AppNotification>[];

  final orders = ref.watch(ordersProvider).valueOrNull ?? const <OrderModel>[];
  for (final o in orders) {
    final t = o.createdAt;
    if (t == null || t.isBefore(cutoff)) continue;
    final n = o.items.length;
    out.add(AppNotification(
      id: 'order-${o.id}',
      kind: NotificationKind.order,
      title: 'New order ${o.id}',
      body: '${o.clientName} requested $n item${n == 1 ? '' : 's'} • ${o.status}',
      time: t,
      route: '/orders/${o.id}',
      urgent: o.isPending,
    ));
  }

  final chemicals = ref.watch(chemicalsProvider).valueOrNull ?? const <ChemicalModel>[];
  for (final c in chemicals) {
    if (!c.isLow) continue;
    final t = c.lastEntryAt ?? c.updatedAt;
    if (t == null || t.isBefore(cutoff)) continue;
    final depleted = c.status == StockStatus.depleted;
    out.add(AppNotification(
      id: 'low-${c.id}',
      kind: NotificationKind.lowStock,
      title: depleted ? '${c.name} is out of stock' : '${c.name} is running low',
      body: '${Fmt.withUnit(c.currentStock, c.unit)} left • minimum ${Fmt.withUnit(c.minimumStock, c.unit)}',
      time: t,
      route: '/chemicals/${c.id}',
      urgent: depleted,
    ));
  }

  out.sort((a, b) => b.time.compareTo(a.time));
  return out;
});