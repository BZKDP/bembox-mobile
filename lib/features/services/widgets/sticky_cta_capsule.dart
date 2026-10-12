import 'package:flutter/material.dart';

import '../../../core/theme/bem_colors.dart';

/// Плавающий нижний CTA — порт `StickyCtaCapsule.tsx` 1:1.
///
/// Белый «бар» со скруглением 26, внутри — коралловая кнопка-градиент
/// (слева title/subtitle, справа сумма с зачёркнутой старой ценой) и
/// опциональная кнопка-корзинка справа со счётчиком.
class StickyCtaCapsule extends StatelessWidget {
  const StickyCtaCapsule({
    super.key,
    required this.show,
    required this.title,
    this.subtitle,
    required this.price,
    this.priceWas,
    this.priceLabel,
    this.onTap,
    this.disabled = false,
    this.onCart,
    this.cartCount = 0,
  });

  final bool show;
  final String title;
  final String? subtitle;

  /// Цена в РУБЛЯХ.
  final int price;
  final int? priceWas;
  final String? priceLabel;
  final VoidCallback? onTap;
  final bool disabled;

  /// Если задан — справа кнопка-корзинка (переход в корзину).
  final VoidCallback? onCart;
  final int cartCount;

  static const _coralGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF7547), Color(0xFFE85522)],
  );

  @override
  Widget build(BuildContext context) {
    final hasDiscount = priceWas != null && priceWas! > price;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: const Cubic(0.22, 0.68, 0.32, 1),
      offset: show ? Offset.zero : const Offset(0, 1.4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        opacity: show ? 1 : 0,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 10),
          // heightFactor:1 — высота по содержимому (не растягиваемся по вертикали),
          // bottomCenter — прижато к низу и центрировано по горизонтали.
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(color: Color(0x38000000), blurRadius: 30, spreadRadius: -10, offset: Offset(0, 12)),
                    BoxShadow(color: Color(0x0D000000), blurRadius: 0, spreadRadius: 1),
                  ],
                ),
                child: Row(
                  children: [
                    // Главная коралловая кнопка.
                    Expanded(
                      child: GestureDetector(
                        onTap: disabled ? null : onTap,
                        child: Opacity(
                          opacity: disabled ? 0.7 : 1,
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: _coralGradient,
                              borderRadius: BorderRadius.circular(19),
                              boxShadow: const [
                                BoxShadow(color: Color(0x99E8551F), blurRadius: 24, spreadRadius: -10, offset: Offset(0, 10)),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3, color: Colors.white,
                                          )),
                                      if (subtitle != null)
                                        Text(subtitle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(alpha: 0.75),
                                            )),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (hasDiscount) ...[
                                      Text('$priceWas ₽',
                                          style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700,
                                            color: Colors.white.withValues(alpha: 0.55),
                                            decoration: TextDecoration.lineThrough,
                                          )),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(priceLabel ?? '$price ₽',
                                        style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4, color: Colors.white,
                                        )),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Кнопка-корзинка.
                    if (onCart != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onCart,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1EC),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(color: BemColors.coral, width: 1.5),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined, size: 22, color: BemColors.coral),
                              if (cartCount > 0)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 20),
                                    height: 20,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE85522),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text('$cartCount',
                                        style: const TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white,
                                        )),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
