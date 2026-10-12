import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bem_colors.dart';
import 'coupon_store.dart';

const _pageBg = Color(0xFFFFFCF6);
const _coral = Color(0xFFFF7547);
const _coralDeep = Color(0xFFE85522);

/// «Купоны и промокоды» — порт `app/profile/coupons/page.tsx`. Карточки купонов;
/// тап → применить (один активный одновременно) и перейти к услуге.
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(couponControllerProvider);
    final notifier = ref.read(couponControllerProvider.notifier);
    final coupons = st.coupons;

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // Шапка.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.canPop() ? context.pop() : context.go('/profile'),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.chevron_left, color: BemColors.ink)),
                ),
                const SizedBox(width: 2),
                const Text('Купоны и промокоды', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink)),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('МОИ КУПОНЫ${coupons.isNotEmpty ? ' · ${coupons.length}' : ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: BemColors.mute)),
            ),
            if (coupons.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x0D000000))),
                child: const Row(children: [
                  Icon(Icons.card_giftcard, size: 28, color: _coral),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Купонов пока нет', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BemColors.ink)),
                    SizedBox(height: 2),
                    Text('Дождитесь новой акции.', style: TextStyle(fontSize: 12, color: BemColors.mute)),
                  ])),
                ]),
              )
            else
              for (final c in coupons)
                _card(context, notifier, c, applied: c.code == st.appliedCode),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, CouponController notifier, Coupon c, {required bool applied}) {
    final meta = couponMeta[c.kind]!;
    return GestureDetector(
      onTap: () { notifier.apply(c.code); context.go(couponRoute(c.kind)); },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: applied ? const Color(0x55FF7547) : const Color(0x0D000000), width: applied ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE2D2), Color(0xFFFFC9A8)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.card_giftcard, size: 24, color: _coralDeep),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(meta.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: BemColors.ink)),
            const SizedBox(height: 1),
            Text(meta.benefit, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: BemColors.mute)),
            const SizedBox(height: 2),
            Text(c.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _coralDeep, letterSpacing: 0.5)),
          ])),
          if (applied)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0x1AFF7547), borderRadius: BorderRadius.circular(999)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check, size: 13, color: _coralDeep),
                SizedBox(width: 3),
                Text('Применён', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _coralDeep)),
              ]),
            )
          else
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Применить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _coral)),
              Icon(Icons.chevron_right, size: 15, color: _coral),
            ]),
        ]),
      ),
    );
  }
}
