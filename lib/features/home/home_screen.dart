import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/bem_bottom_nav.dart';
import 'widgets/home_hero.dart';
import 'widgets/promo_banner.dart';
import 'widgets/quick_order.dart';

/// Главный экран — порт `apps/web/app/page.tsx` (вкладка «Главная»):
/// HomeHero + PromoBanner + QuickOrder, снизу — нав-бар.
///
/// Контент ограничен по ширине (как `max-w-md` на сайте) и центрируется —
/// чтобы на планшетах не растягивался.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF6), // бежевый фон как на сайте (не белый)
      extendBody: true, // контент уходит ПОД плавающую стеклянную пилюлю
      bottomNavigationBar: const BemBottomNav(),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448), // ≈ tailwind max-w-md (28rem)
            child: ListView(
              // shrinkWrap + clamping: список не выше своего контента и без
              // «отскока» — поэтому нельзя проскроллить в пустоту под сеткой.
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: const [
                HomeHero(),
                PromoBanner(),
                QuickOrder(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
