import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import 'widgets/category_tile.dart';
import 'widgets/product_card.dart';
import 'widgets/products_top_bar.dart';

const _pageBg = Color(0xFFFFFCF6);

/// Экран категории (parent=id) — порт `PcatView` 1:1: белый pill с крошками
/// «‹ Разделы | путь», горизонтальная лента подкатегорий (плитки 92), сетка
/// товаров grid-cols-2. Без AppBar и без заголовка-риски (как на сайте).
class ProductCategoryScreen extends ConsumerWidget {
  const ProductCategoryScreen({super.key, required this.catId});
  final String catId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(catalogProvider(catId));
    return Scaffold(
      backgroundColor: _pageBg,
      body: async.when(
          loading: () => Column(children: [
            const ProductsTopBar(),
            const Expanded(child: Center(child: CircularProgressIndicator(color: BemColors.coral))),
          ]),
          error: (e, _) => Column(children: [
            const ProductsTopBar(),
            Expanded(child: Center(
              child: TextButton(
                onPressed: () => ref.invalidate(catalogProvider(catId)),
                child: const Text('Повторить', style: TextStyle(color: BemColors.coral, fontWeight: FontWeight.w800)),
              ),
            )),
          ]),
          data: (c) {
            final crumbs = c.breadcrumb;
            final curName = crumbs.isNotEmpty ? crumbs.last.name : null;
            return CustomScrollView(
              slivers: [
                // Шапка раздела (адрес + поиск + ❤) — как на сайте остаётся.
                const SliverToBoxAdapter(child: ProductsTopBar()),
                // Крошки: белый pill «‹ Разделы | путь».
                SliverToBoxAdapter(child: _breadcrumb(context, crumbs)),
                // Подкатегории — лента плиток 92.
                if (c.subcats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            for (var i = 0; i < c.subcats.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              CategoryTile(
                                name: c.subcats[i].name,
                                parentName: curName,
                                size: 92,
                                labelWeight: FontWeight.w700,
                                onTap: () => context.push('/services/products/cat/${c.subcats[i].id}'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                // Товары — сетка 2 колонки.
                if (c.products.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: productCardHeight,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => ProductCard(product: c.products[i], width: double.infinity),
                        childCount: c.products.length,
                      ),
                    ),
                  )
                else if (c.subcats.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('В этой категории пока нет товаров на складе', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: BemColors.mute)),
                    )),
                  ),
              ],
            );
          },
        ),
    );
  }

  Widget _breadcrumb(BuildContext context, List<({String id, String name})> crumbs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [BoxShadow(color: Color(0x2E281E14), blurRadius: 10, spreadRadius: -6, offset: Offset(0, 2)), BoxShadow(color: Color(0x0D000000), spreadRadius: 1)],
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // «‹ Разделы».
                GestureDetector(
                  onTap: () => context.canPop() ? context.go('/services/products') : context.go('/services/products'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.chevron_left, size: 16, color: BemColors.coral),
                      SizedBox(width: 2),
                      Text('Разделы', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: BemColors.ink)),
                    ]),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0x12000000), indent: 8, endIndent: 8),
                // Путь — скроллится, последний жирный.
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // показываем конец пути
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < crumbs.length; i++) ...[
                            if (i > 0) const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(Icons.chevron_right, size: 11, color: Color(0x8C9C8E84)),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/services/products/cat/${crumbs[i].id}'),
                              child: Text(crumbs[i].name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: i == crumbs.length - 1 ? FontWeight.w800 : FontWeight.w600,
                                    color: i == crumbs.length - 1 ? BemColors.ink : BemColors.mute,
                                  )),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
