import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import 'favorites_store.dart';
import 'widgets/product_card.dart';

const _pageBg = Color(0xFFFFFCF6);

/// Деталь товара — порт `app/services/products/[id]/page.tsx`.
/// Шапка (назад + категория + название + ❤), hero-фото, цена/бренд, КБЖУ,
/// описание, состав, срок, похожие товары и липкая кнопка добавления.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productDetailProvider(id));
    return Scaffold(
      backgroundColor: _pageBg,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: BemColors.coral)),
        error: (e, _) => _error(context),
        data: (p) => _content(context, ref, p),
      ),
    );
  }

  Widget _error(BuildContext context) => SafeArea(
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => _back(context))),
            const Expanded(child: Center(child: Text('Не удалось загрузить товар', style: TextStyle(color: BemColors.mute)))),
          ],
        ),
      );

  void _back(BuildContext context) => context.canPop() ? context.pop() : context.go('/services/products');

  Widget _content(BuildContext context, WidgetRef ref, ProductDetail p) {
    const etaColor = BemColors.coral;
    final isFav = ref.watch(favoritesProvider.select((s) => s.contains('product:${p.id}')));
    final qty = ref.watch(cartControllerProvider.select((c) => c.items[p.id] ?? 0));
    final k = p.kbju;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // Шапка.
            Padding(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _squareBtn(const Icon(Icons.chevron_left, size: 24, color: Color(0xFF55555A)), () => _back(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(p.name,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.15, color: BemColors.ink)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _squareBtn(
                    Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 20, color: isFav ? BemColors.coral : BemColors.ink2),
                    () { ref.read(favoritesProvider.notifier).toggle('product:${p.id}'); HapticFeedback.selectionClick(); },
                  ),
                ],
              ),
            ),
            // HERO-фото с бейджем ETA.
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2))],
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: p.imageUrl == null
                        ? const Icon(Icons.image_outlined, size: 64, color: BemColors.mute)
                        : CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
            // Цена / бренд.
            _card(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${p.price} ₽',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: BemColors.ink)),
                    if (p.oldPrice != null && p.oldPrice! > p.price) ...[
                      const SizedBox(width: 8),
                      Text('${p.oldPrice} ₽',
                          style: const TextStyle(fontSize: 16, color: BemColors.mute, decoration: TextDecoration.lineThrough)),
                    ],
                    const Spacer(),
                    if (p.unit != null) Text(p.unit!, style: const TextStyle(fontSize: 12, color: BemColors.mute)),
                  ],
                ),
                if (p.brand != null) Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Бренд: ${p.brand}', style: const TextStyle(fontSize: 12.5, color: BemColors.mute)),
                ),
              ],
            )),
            // КБЖУ.
            if (k != null && k.hasAny)
              _card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('КБЖУ НА 100 Г', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: BemColors.mute)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _kbjuCell('ккал', k.kcal),
                    _kbjuCell('белки', k.protein),
                    _kbjuCell('жиры', k.fat),
                    _kbjuCell('углев', k.carb),
                  ]),
                ],
              )),
            if (p.description != null && p.description!.isNotEmpty)
              _card(child: _section('ОПИСАНИЕ', p.description!, BemColors.ink)),
            if (p.composition != null && p.composition!.isNotEmpty)
              _card(child: _section('СОСТАВ', p.composition!, BemColors.mute)),
            if (p.shelfLife != null && p.shelfLife!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text('Срок годности: ${p.shelfLife}', style: const TextStyle(fontSize: 12, color: BemColors.mute)),
              ),
            // Похожие.
            if (p.category != null && p.category!.isNotEmpty)
              _Similar(catId: p.category!, currentId: p.id),
          ],
        ),
        // Липкая кнопка.
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _cta(ref, p, etaColor, qty),
          ),
        ),
      ],
    );
  }

  Widget _cta(WidgetRef ref, ProductDetail p, Color etaColor, int qty) {
    final notifier = ref.read(cartControllerProvider.notifier);
    CartProduct item() => CartProduct(
          id: p.id, name: p.name, unit: p.unit, price: p.price,
          kind: 'product', shopSlug: 'bembox-own', image: p.imageUrl, etaMinutes: p.etaMinutes,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 8)), BoxShadow(color: Color(0x0D000000), spreadRadius: 1)],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.unit != null) Text(p.unit!, style: const TextStyle(fontSize: 10.5, color: BemColors.mute)),
              Text('${p.price * (qty < 1 ? 1 : qty)} ₽',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BemColors.ink)),
            ],
          ),
          const Spacer(),
          if (qty > 0)
            Container(
              height: 44,
              decoration: BoxDecoration(color: etaColor, borderRadius: BorderRadius.circular(999)),
              child: Row(children: [
                _ctaBtn(Icons.remove, () => notifier.remove(p.id)),
                Text('$qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                _ctaBtn(Icons.add, () { notifier.add(item()); HapticFeedback.selectionClick(); }),
              ]),
            )
          else
            GestureDetector(
              onTap: () { notifier.add(item()); HapticFeedback.lightImpact(); },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: etaColor, borderRadius: BorderRadius.circular(999)),
                alignment: Alignment.center,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('В корзину', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ctaBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 42, height: 44, child: Icon(icon, size: 18, color: Colors.white)),
      );

  Widget _kbjuCell(String label, double? v) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF8F8F4), borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(v == null ? '—' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1)),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BemColors.ink)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 9.5, color: BemColors.mute)),
            ],
          ),
        ),
      );

  Widget _section(String title, String body, Color bodyColor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: BemColors.mute)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(fontSize: 13, height: 1.45, color: bodyColor)),
        ],
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2))],
        ),
        child: child,
      );

  Widget _squareBtn(Widget child, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 3))]),
          child: child,
        ),
      );
}

/// Похожие товары — горизонтальная лента по категории текущего товара.
class _Similar extends ConsumerWidget {
  const _Similar({required this.catId, required this.currentId});
  final String catId;
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<SearchResult>(
      future: ref.read(productsApiProvider).search(cat: catId, eta: 'all', limit: 12),
      builder: (context, snap) {
        final items = (snap.data?.items ?? const <ApiProduct>[])
            .where((p) => p.id != currentId).take(10).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Похожие товары',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: BemColors.ink)),
            ),
            SizedBox(
              height: 248,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => ProductCard(product: items[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}
