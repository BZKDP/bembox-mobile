import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/product.dart';
import 'favorites_store.dart';

const _sheetBg = Color(0xFFFFFCF6);
const _coral = Color(0xFFFF7547);

/// Открыть карточку товара ШТОРКОЙ снизу — порт `ProductDetailSheet.tsx`
/// (сверено с живым сайтом: 4 круглые кнопки share/fav/cart/×, бежевый фон).
Future<void> showProductSheet(BuildContext context, String id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => ProductSheet(id: id),
  );
}

class ProductSheet extends ConsumerStatefulWidget {
  const ProductSheet({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<ProductSheet> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productDetailProvider(widget.id));
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: _sheetBg,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: async.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: _coral)),
                      error: (e, _) => const Center(child: Text('Не удалось загрузить товар', style: TextStyle(color: BemColors.mute))),
                      data: _body,
                    ),
                  ),
                  async.maybeWhen(data: _bottomBar, orElse: () => const SizedBox.shrink()),
                ],
              ),
              // Хваталка по центру сверху.
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(color: const Color(0x26000000), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // 4 круглые стеклянные кнопки справа-сверху, ПОВЕРХ фото.
              Positioned(top: 12, right: 12, child: _topButtons()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topButtons() {
    final id = widget.id;
    final isFav = ref.watch(favoritesProvider.select((s) => s.contains('product:$id')));
    final cartQty = ref.watch(cartControllerProvider.select((c) => c.totalQty));
    return Row(children: [
      _circleBtn(
        child: const Icon(Icons.ios_share, size: 17, color: BemColors.ink2),
        onTap: () {
          Clipboard.setData(ClipboardData(text: '${AppConfig.siteBaseUrl}/services/products/$id'));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
        },
      ),
      const SizedBox(width: 8),
      _circleBtn(
        child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 17, color: isFav ? _coral : BemColors.ink2),
        onTap: () { ref.read(favoritesProvider.notifier).toggle('product:$id'); HapticFeedback.selectionClick(); },
      ),
      const SizedBox(width: 8),
      _circleBtn(
        child: const Icon(Icons.shopping_bag_outlined, size: 17, color: BemColors.ink2),
        badge: cartQty > 0 ? cartQty : null,
        onTap: () { Navigator.of(context).pop(); context.push('/cart'); },
      ),
      const SizedBox(width: 8),
      _circleBtn(
        child: const Icon(Icons.close, size: 18, color: BemColors.ink2),
        onTap: () => Navigator.of(context).pop(),
      ),
    ]);
  }

  Widget _circleBtn({required Widget child, required VoidCallback onTap, int? badge}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 12, spreadRadius: -4, offset: Offset(0, 4))]),
            child: Center(child: child),
          ),
          if (badge != null)
            Positioned(
              top: -3, right: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: const Color(0xFFE85522), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.5)),
                alignment: Alignment.center,
                child: Text('$badge', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
        ]),
      );

  Widget _body(ProductDetail p) {
    final k = p.kbju;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 0, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          // Большое фото (белая подложка).
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: Colors.white,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: p.imageUrl == null
                      ? Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w800, color: Color(0x331A1410)))
                      : CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          // Название + единица.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: p.name),
                if (p.unit != null && p.unit!.isNotEmpty)
                  TextSpan(text: '  ${p.unit}', style: const TextStyle(color: BemColors.mute)),
              ]),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15, color: BemColors.ink),
            ),
          ),
          // Описание.
          if (p.description != null && p.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  p.description!,
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: BemColors.ink2),
                ),
              ),
            ),
          // «Спросить помощника» — белая кнопка с обводкой (как на живом сайте).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GestureDetector(
              onTap: () { Navigator.of(context).pop(); context.push('/services/request'); },
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFE7D4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome, size: 16, color: _coral),
                  SizedBox(width: 8),
                  Text('Спросить помощника', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BemColors.ink)),
                ]),
              ),
            ),
          ),
          // Пищевая ценность.
          if (k != null && k.hasAny) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Text('ПИЩЕВАЯ ЦЕННОСТЬ · НА 100 Г', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: BemColors.mute)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _kbju('ккал', k.kcal), _kbju('белки', k.protein), _kbju('жиры', k.fat), _kbju('угл', k.carb),
              ]),
            ),
          ],
          // Состав / срок / бренд.
          if (p.composition != null && p.composition!.isNotEmpty) _section('Состав', p.composition!),
          if (p.shelfLife != null && p.shelfLife!.isNotEmpty) _section('Срок и хранение', p.shelfLife!),
          if (p.brand != null && p.brand!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Бренд: ${p.brand}', style: const TextStyle(fontSize: 13, color: BemColors.mute)),
            ),
        ],
      ),
    );
  }

  /// Липкая нижняя панель: цена слева + степпер (если в корзине) / «В корзину».
  Widget _bottomBar(ProductDetail p) {
    final qty = ref.watch(cartControllerProvider.select((c) => c.items[p.id] ?? 0));
    final hasDiscount = p.oldPrice != null && p.oldPrice! > p.price;
    final notifier = ref.read(cartControllerProvider.notifier);
    CartProduct item() => CartProduct(id: p.id, name: p.name, unit: p.unit, price: p.price, kind: 'product', shopSlug: 'bembox-own', image: p.imageUrl, etaMinutes: p.etaMinutes);
    return Container(
      decoration: const BoxDecoration(
        // Плавный переход от прозрачного бежевого к фону.
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FFFCF6), _sheetBg], stops: [0, 0.35]),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.price} ₽', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink)),
                if (hasDiscount)
                  Text('${p.oldPrice} ₽', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xB39C8E84), decoration: TextDecoration.lineThrough)),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: qty > 0
                  ? Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x80FF7547), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 10))]),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _bBtn(Icons.remove, () => notifier.remove(p.id)),
                        Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        _bBtn(Icons.add, () { notifier.add(item()); HapticFeedback.selectionClick(); }),
                      ]),
                    )
                  : GestureDetector(
                      onTap: () { notifier.add(item()); HapticFeedback.lightImpact(); },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(color: _coral, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x80FF7547), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 10))]),
                        alignment: Alignment.center,
                        child: const Text('В корзину', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bBtn(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: SizedBox(width: 48, height: 56, child: Icon(icon, size: 18, color: Colors.white)));

  Widget _kbju(String label, double? v) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF5F2EB), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(v == null ? '—' : (v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1)), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BemColors.ink)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10.5, color: BemColors.mute)),
          ]),
        ),
      );

  Widget _section(String title, String body) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: BemColors.mute)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4, color: BemColors.ink2)),
        ]),
      );
}
