import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/bem_colors.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/product.dart';
import '../favorites_store.dart';
import '../product_sheet.dart';

/// Высота карточки товара (фиксирована — как `h-full` + фото 140 на сайте).
/// Используется в сетках как mainAxisExtent и в рядах как высота ListView.
const double productCardHeight = 222;

/// Карточка товара — 1:1 с ЖИВЫМ bembox.ru (снято из DOM 2026-06-07):
/// фото-зона 140px (белая), ❤ в углу, коралловый «стеклянный» «+» 36px на стыке
/// фото/инфо, цена 17px, название 12.5px в 2 строки. Тап → шторка товара.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product, this.width = 160});
  final ApiProduct product;
  final double width;

  static const _coralGlass = Color(0xE0FF7547); // rgba(255,117,71,0.88)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartControllerProvider.select((c) => c.items[product.id] ?? 0));
    final isFav = ref.watch(favoritesProvider.select((s) => s.contains('product:${product.id}')));
    final hasDiscount = product.oldPrice != null && product.oldPrice! > product.price;
    final discountPct = hasDiscount ? (100 - (product.price / product.oldPrice! * 100).round()) : 0;

    void open() => showProductSheet(context, product.id);

    return GestureDetector(
      onTap: open,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          // На сайте у карточки НЕТ тени-блюра — только волосок-рамка
          // box-shadow: 0 0 0 1px rgba(0,0,0,0.07) (ProductCardV2.cardShadow).
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 0, spreadRadius: 1),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото-зона 140px (белая) + ❤ + «+» на стыке.
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: Colors.white,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: product.imageUrl == null
                        ? Text(product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0x401A1410)))
                        : CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, _) => const SizedBox(),
                            errorWidget: (_, _, _) => const Icon(Icons.image_outlined, color: BemColors.mute),
                          ),
                  ),
                ),
                // «Заморожено» / скидка −% — на стыке слева.
                if (discountPct >= 5)
                  Positioned(
                    left: 8, bottom: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8231C), borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Color(0x73E8231C), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 3))],
                      ),
                      child: Text('−$discountPct%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                // ❤ избранное — белый кружок 32.
                Positioned(
                  right: 8, top: 8,
                  child: GestureDetector(
                    onTap: () { ref.read(favoritesProvider.notifier).toggle('product:${product.id}'); HapticFeedback.selectionClick(); },
                    child: Container(
                      width: 32, height: 32,
                      decoration: const BoxDecoration(color: Color(0xF2FFFFFF), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 4)]),
                      child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 15, color: isFav ? BemColors.coral : BemColors.ink2),
                    ),
                  ),
                ),
                // «+» / степпер — коралловый стеклянный 36px на стыке фото/инфо.
                Positioned(
                  right: 8, bottom: -18,
                  child: qty > 0 ? _stepper(ref) : _plus(ref),
                ),
              ],
            ),
            // Инфо: цена крупно, имя в 2 строки.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${product.price} ₽',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: hasDiscount ? const Color(0xFFE8231C) : BemColors.ink)),
                        if (hasDiscount) ...[
                          const SizedBox(width: 5),
                          Text('${product.oldPrice} ₽',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0x999C8E84), decoration: TextDecoration.lineThrough)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: product.name),
                        if (product.unit != null && product.unit!.isNotEmpty)
                          TextSpan(text: ' ${product.unit}', style: const TextStyle(color: Color(0xB39C8E84))),
                      ]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.25, fontWeight: FontWeight.w400, color: Color(0xD91A1410)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  CartProduct _toCart() => CartProduct(
        id: product.id, name: product.name, unit: product.unit, price: product.price,
        kind: 'product', shopSlug: 'bembox-own', image: product.imageUrl, etaMinutes: product.etaMinutes,
      );

  Widget _plus(WidgetRef ref) => GestureDetector(
        onTap: () { ref.read(cartControllerProvider.notifier).add(_toCart()); HapticFeedback.selectionClick(); },
        child: Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(
            color: _coralGlass,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x66FF7547), blurRadius: 14, spreadRadius: -6, offset: Offset(0, 6))],
          ),
          child: const Icon(Icons.add, size: 20, color: Colors.white),
        ),
      );

  Widget _stepper(WidgetRef ref) {
    final notifier = ref.read(cartControllerProvider.notifier);
    final qty = ref.watch(cartControllerProvider.select((c) => c.items[product.id] ?? 0));
    // Белый степпер с тёмными иконками (как на сайте при qty>0).
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: [BoxShadow(color: Color(0x2E14100C), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 6)), BoxShadow(color: Color(0x0F14100C), spreadRadius: 1)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sq(Icons.remove, () => notifier.remove(product.id)),
          Text('$qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BemColors.ink)),
          _sq(Icons.add, () { notifier.add(_toCart()); HapticFeedback.selectionClick(); }),
        ],
      ),
    );
  }

  Widget _sq(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 34, height: 36, child: Icon(icon, size: 16, color: BemColors.ink2)),
      );
}
