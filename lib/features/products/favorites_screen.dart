import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/product.dart';
import 'favorites_store.dart';
import 'widgets/product_card.dart';

const _pageBg = Color(0xFFFFFCF6);

/// Экран «Любимое» — товары из избранного (ключи `product:<id>`),
/// подгружаются через `/products/search?ids=...`.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoritesProvider)
        .where((k) => k.startsWith('product:'))
        .map((k) => k.substring('product:'.length))
        .toList();

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: BemColors.ink,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.canPop() ? context.pop() : context.go('/services/products'),
        ),
        title: const Text('Любимое', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
      ),
      body: ids.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 40, color: BemColors.mute),
                    SizedBox(height: 12),
                    Text('Пока пусто', style: TextStyle(fontWeight: FontWeight.w800, color: BemColors.ink)),
                    SizedBox(height: 4),
                    Text('Жмите ❤ на карточках товаров', style: TextStyle(fontSize: 12.5, color: BemColors.mute)),
                  ],
                ),
              ),
            )
          : FutureBuilder<SearchResult>(
              future: ref.read(productsApiProvider).search(ids: ids, eta: 'all', limit: 100),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: BemColors.coral));
                final items = snap.data!.items;
                if (items.isEmpty) {
                  return const Center(child: Text('Товары недоступны', style: TextStyle(color: BemColors.mute)));
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: productCardHeight,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => ProductCard(product: items[i], width: double.infinity),
                );
              },
            ),
    );
  }
}
