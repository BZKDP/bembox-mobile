import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/api/orders_api.dart';
import '../home/widgets/bem_bottom_nav.dart';

const _pageBg = Color(0xFFFFFCF6);

/// Статус заказа → подпись + цвета бейджа (из globals.css .badge-*).
({String label, Color bg, Color fg}) _statusStyle(String s) {
  switch (s) {
    case 'paid':
      return (label: 'Оплачен', bg: BemColors.badgePaidBg, fg: BemColors.badgePaidFg);
    case 'picking':
      return (label: 'Собираем', bg: BemColors.badgePickingBg, fg: BemColors.badgePickingFg);
    case 'delivering':
      return (label: 'Везём', bg: BemColors.badgeDeliveringBg, fg: BemColors.badgeDeliveringFg);
    case 'delivered':
    case 'completed':
      return (label: 'Доставлен', bg: BemColors.badgeDeliveredBg, fg: BemColors.badgeDeliveredFg);
    case 'cancelled':
      return (label: 'Отменён', bg: BemColors.badgeCancelledBg, fg: BemColors.badgeCancelledFg);
    default: // created
      return (label: 'Создан', bg: BemColors.badgeCreatedBg, fg: BemColors.badgeCreatedFg);
  }
}

/// Экран «Заказы» — активные заказы пользователя (`/api/orders/active`).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeOrdersProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) (context.canPop() ? context.pop() : context.go('/home')); },
      child: Scaffold(
      backgroundColor: _pageBg,
      extendBody: true, // контент уходит ПОД плавающую стеклянную пилюлю
      bottomNavigationBar: const BemBottomNav(),
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: BemColors.ink,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
        title: const Text('Заказы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: BemColors.coral)),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(activeOrdersProvider),
            child: const Text('Повторить', style: TextStyle(color: BemColors.coral, fontWeight: FontWeight.w800)),
          ),
        ),
        data: (orders) => orders.isEmpty
            ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.receipt_long_outlined, size: 44, color: BemColors.mute),
                  SizedBox(height: 12),
                  Text('Активных заказов нет', style: TextStyle(fontWeight: FontWeight.w800, color: BemColors.ink)),
                ]),
              )
            : RefreshIndicator(
                color: BemColors.coral,
                onRefresh: () async => ref.invalidate(activeOrdersProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(orders[i]),
                ),
              ),
      ),
      ),
    );
  }

  Widget _card(OrderSummary o) {
    final st = _statusStyle(o.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Заказ ${o.number}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BemColors.ink))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(999)),
              child: Text(st.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: st.fg)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('${o.total} ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink)),
            const Spacer(),
            if (o.etaMinutes != null)
              Text('~${o.etaMinutes} мин', style: const TextStyle(fontSize: 12.5, color: BemColors.mute)),
          ]),
        ],
      ),
    );
  }
}
