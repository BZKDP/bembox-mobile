import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/product.dart';
import 'widgets/product_card.dart';

const _pageBg = Color(0xFFFFFCF6);

/// Экран поиска товаров. Поле ввода (дебаунс 320мс), сетка результатов,
/// did-you-mean подсказка при нуле находок.
class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  SearchResult? _result;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() { _result = null; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ref.read(productsApiProvider).search(q: q, eta: 'all', limit: 40);
      if (mounted && _lastQuery == q) setState(() { _result = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _result = const SearchResult(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Поле поиска + назад.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.canPop() ? context.pop() : context.go('/services/products'),
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF55555A)),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: BemColors.soft, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 20, color: BemColors.mute),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              onChanged: _onChanged,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (v) => _run(v.trim()),
                              style: const TextStyle(fontSize: 14, color: BemColors.ink),
                              decoration: const InputDecoration(
                                isCollapsed: true, border: InputBorder.none,
                                hintText: 'Найти товар, бренд…',
                                hintStyle: TextStyle(fontSize: 14, color: BemColors.mute),
                              ),
                            ),
                          ),
                          if (_ctrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () { _ctrl.clear(); _run(''); setState(() {}); },
                              child: const Icon(Icons.close, size: 18, color: BemColors.mute),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: BemColors.coral));
    final r = _result;
    if (r == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Начните вводить название товара или бренда',
              textAlign: TextAlign.center, style: TextStyle(color: BemColors.mute)),
        ),
      );
    }
    if (r.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ничего не нашли', style: TextStyle(fontWeight: FontWeight.w800, color: BemColors.ink)),
              if (r.suggestion != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () { _ctrl.text = r.suggestion!; _run(r.suggestion!); },
                  child: Text('Может быть, «${r.suggestion}»?',
                      style: const TextStyle(color: BemColors.coral, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: productCardHeight,
      ),
      itemCount: r.items.length,
      itemBuilder: (_, i) => ProductCard(product: r.items[i], width: double.infinity),
    );
  }
}
