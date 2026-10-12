import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/bem_colors.dart';
import '../../address/map_sheet.dart';

const _coral = Color(0xFFFF7547);
const _border = Color(0x0F000000); // 0 0 0 1px rgba(0,0,0,0.06)

/// Шапка раздела «Продукты» — порт `CompactHeader` + строки поиска с прода
/// (/opt/bembox). Ряд 1: ‹ назад · адрес-пилюля · ♡ избранное. Ряд 2: поиск
/// (белый, rounded-2xl, тёмная круглая кнопка-лупа справа).
class ProductsTopBar extends ConsumerWidget {
  const ProductsTopBar({super.key, this.backFallback = '/home'});
  final String backFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';
    return Column(
      children: [
        // ── Ряд 1: назад + адрес + избранное ──
        Padding(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 6),
          child: Row(children: [
            _squareBtn(
              child: const Icon(Icons.chevron_left, size: 22, color: Color(0xFF55555A)),
              onTap: () => context.canPop() ? context.pop() : context.go(backFallback),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => showAddressMapSheet(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on, size: 14, color: _coral),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address.isEmpty ? 'Выберите адрес' : address,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BemColors.ink),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: BemColors.mute),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _squareBtn(
              child: const Icon(Icons.favorite_border, size: 18, color: BemColors.ink2),
              onTap: () => context.push('/services/products/favorites'),
            ),
          ]),
        ),
        // ── Ряд 2: поиск ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: GestureDetector(
            onTap: () => context.push('/services/products/search'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48,
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                const Expanded(
                  child: Text('Молоко, хлеб, сыр…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: BemColors.mute)),
                ),
                // Тёмная круглая кнопка-лупа справа (как на сайте).
                Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: Color(0x8C24201C), shape: BoxShape.circle),
                  child: const Icon(Icons.search, size: 16, color: Colors.white),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  /// Белый квадрат 40×40 rounded-12 + тонкая рамка (как back/♡ на сайте).
  Widget _squareBtn({required Widget child, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Center(child: child),
        ),
      );
}
