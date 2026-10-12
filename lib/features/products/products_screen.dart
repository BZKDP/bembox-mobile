import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/product.dart';
import '../home/widgets/bem_bottom_nav.dart';
import 'widgets/category_tile.dart';
import 'widgets/product_card.dart';
import 'widgets/products_top_bar.dart';

const _pageBg = Color(0xFFFFFCF6); // PAGE_BG с сайта

/// Порядок ЧИПСОВ как на сайте (с «Готовой едой», без «Бакалеи»).
const _chipOrder = [
  'Молочное', 'Хлеб и выпечка', 'Сладости и снеки', 'Мясо и птица', 'Готовая еда',
  'Рыба и морепродукты', 'Замороженные продукты', 'Вода и напитки',
  'Чай, кофе и какао', 'Для детей', 'Бытовая химия', 'Гигиена и косметика', 'Хозтовары',
];
const _sectionExclude = {'Готовая еда'};

/// Экран «Продукты» — порт `app/services/products/page.tsx` (дашборд).
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(catalogProvider(null));
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      backgroundColor: _pageBg,
      extendBody: true, // контент уходит ПОД плавающую стеклянную пилюлю
      bottomNavigationBar: const BemBottomNav(),
      body: Stack(
        children: [
          root.when(
            loading: () => const Center(child: CircularProgressIndicator(color: BemColors.coral)),
            error: (e, _) => _error(context, ref),
            data: (cat) {
              final byName = {for (final c in cat.subcats) c.name: c};
              final chipCats = [
                for (final n in _chipOrder)
                  if (byName[n] != null && byName[n]!.count > 0) byName[n]!,
              ];
              final sectionCats = chipCats.where((c) => !_sectionExclude.contains(c.name)).toList();
              return ListView(
                padding: const EdgeInsets.only(bottom: 130),
                children: [
                  const ProductsTopBar(),
                  if (chipCats.isNotEmpty) _catLane(context, chipCats),
                  if (cat.products.isNotEmpty)
                    _Lane(title: 'Популярное', products: cat.products),
                  for (final c in sectionCats)
                    _CategorySection(cat: c),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          // Компактная пилюля корзины снизу-справа (как на живом сайте):
          // «{сумма} ₽ 🛒{кол-во}». Никакой широкой кнопки «В корзину».
          if (cart.totalQty > 0)
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: () => context.push('/cart'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
                  decoration: BoxDecoration(
                    color: BemColors.coral,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: Color(0x80FF7547), blurRadius: 22, spreadRadius: -6, offset: Offset(0, 10))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${cart.totalPrice} ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(width: 10),
                    Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                        child: const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white),
                      ),
                      Positioned(
                        top: -3, right: -3,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 17),
                          height: 17,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE85522), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.5)),
                          alignment: Alignment.center,
                          child: Text('${cart.totalQty}', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Лента плиток-категорий (порт CategoryPager: 78px тайлы, gap 2.5).
  Widget _catLane(BuildContext context, List<PCat> cats) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < cats.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                CategoryTile(name: cats[i].name, onTap: () => context.push('/services/products/cat/${cats[i].id}')),
              ],
            ],
          ),
        ),
      );

  Widget _error(BuildContext context, WidgetRef ref) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Не удалось загрузить каталог', style: TextStyle(color: BemColors.mute)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(catalogProvider(null)),
              child: const Text('Повторить', style: TextStyle(color: BemColors.coral, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}

/// Секция-категория: подгружает свои товары и показывает горизонтальным рядом.
class _CategorySection extends ConsumerWidget {
  const _CategorySection({required this.cat});
  final PCat cat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(catalogProvider(cat.id));
    return data.maybeWhen(
      data: (c) => c.products.isEmpty
          ? const SizedBox.shrink()
          : _Lane(
              title: cat.name,
              products: c.products,
              onSeeAll: () => context.push('/services/products/cat/${cat.id}'),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Секция-лента — порт `Lane` + `CardRail`: заголовок 22px жирный, «Все» серой
/// капсулой, горизонтальный ряд карточек (ширина 158).
class _Lane extends StatelessWidget {
  const _Lane({required this.title, required this.products, this.onSeeAll});
  final String title;
  final List<ApiProduct> products;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.1, color: BemColors.ink)),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFFF0EDE6), borderRadius: BorderRadius.circular(999)),
                      child: const Row(children: [
                        Text('Все', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BemColors.ink)),
                        Icon(Icons.chevron_right, size: 16, color: Color(0xB31A1410)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: productCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => ProductCard(product: products[i], width: 158),
            ),
          ),
        ],
      ),
    );
  }
}

