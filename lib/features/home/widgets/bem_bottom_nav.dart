import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/bem_colors.dart';

/// Нижняя навигация — порт `BottomNavGlass.tsx` (живой сайт). Самодостаточна:
/// активная вкладка берётся из текущего маршрута, переход — внутри.
/// 5 вкладок: Главное · Помощник · Поддержка · Корзина · Я.
class BemBottomNav extends ConsumerWidget {
  const BemBottomNav({super.key});

  static const double _slotW = 62;
  static const double _indW = 50;
  static const double _h = 60;

  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Главное', route: '/home'),
    (icon: Icons.chat_bubble_outline, label: 'Помощник', route: '/services/request'),
    (icon: Icons.headset_mic_outlined, label: 'Поддержка', route: '/support'),
    (icon: Icons.shopping_bag_outlined, label: 'Корзина', route: '/cart'),
    (icon: Icons.person_outline, label: 'Я', route: '/profile'),
  ];

  int _indexFor(String loc) {
    if (loc.startsWith('/services/request')) return 1;
    if (loc.startsWith('/support')) return 2;
    if (loc.startsWith('/cart')) return 3;
    if (loc.startsWith('/profile') || loc.startsWith('/orders')) return 4;
    if (loc == '/' || loc.startsWith('/home')) return 0;
    return -1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartControllerProvider).totalQty;
    final loc = GoRouterState.of(context).uri.toString();
    final current = _indexFor(loc);
    // Подписи не масштабируем системным размером шрифта — иначе они распирают
    // слоты и нав уходит в overflow.
    return MediaQuery.withNoTextScaling(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: _tabs.length * _slotW,
                  height: _h,
                  // Бордер — через foregroundDecoration, чтобы НЕ съедал ширину
                  // контента (иначе Row на 2px вылезал → overflow).
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0x12000000)),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 22, spreadRadius: -10, offset: Offset(0, 8))],
                  ),
                  child: Stack(
                    children: [
                      if (current >= 0)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: const Cubic(0.4, 0, 0.2, 1),
                          left: current * _slotW + (_slotW - _indW) / 2,
                          top: (_h - 44) / 2,
                          child: Container(
                            width: _indW, height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 9, spreadRadius: -3, offset: Offset(0, 3))],
                            ),
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _tabs.length; i++) _item(context, i, current, cartCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int i, int current, int cartCount) {
    final t = _tabs[i];
    final active = i == current;
    final color = active ? BemColors.coral : BemColors.mute;
    final isCart = i == 3;
    return GestureDetector(
      onTap: () { if (i != current) context.go(t.route); },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _slotW,
        height: _h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(t.icon, size: 19, color: color),
                if (isCart && cartCount > 0)
                  Positioned(
                    top: -6, right: -8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 15),
                      height: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE85522), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.5)),
                      alignment: Alignment.center,
                      child: Text('$cartCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: _slotW,
              child: Text(
                t.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
