import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/cart_item.dart';
import '../coupons/coupon_store.dart';
import 'widgets/address_top_bar.dart';
import 'widgets/sticky_cta_capsule.dart';

/// Тип пакета мусора — данные 1:1 из массива PACKS в `services/trash/page.tsx`.
class _Pack {
  const _Pack(this.id, this.label, this.hint, this.weight, this.price);
  final int id;
  final String label;
  final String hint;
  final String weight;
  final int price;
}

const _packs = <_Pack>[
  _Pack(1, '1 пакет', 'один обычный', 'до 5 кг', 49),
  _Pack(2, '2 пакета', 'два пятёрочных', 'до 10 кг', 80),
  _Pack(3, '3 пакета', 'три обычных', 'до 15 кг', 100),
  _Pack(4, '4 пакета', 'или два 100-литровых', 'до 30 кг', 110),
];

const _accent = BemColors.coral;

/// Экран «Вынос мусора» — порт `app/services/trash/page.tsx` 1:1.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  int _packIdx = 0;
  int? _flippedIdx;
  bool _submitting = false;

  /// Купон first-trash активен (бесплатных мусорных позиций в корзине ещё нет).
  bool get _giveFree {
    final hasCoupon = ref.read(couponControllerProvider.notifier).effectiveFor('trash') != null;
    final items = ref.read(cartControllerProvider).items;
    final hasFreeInCart = items.keys.any((id) => id.startsWith('svc:trash:') && id.endsWith(':free'));
    return hasCoupon && !hasFreeInCart;
  }

  void _addPack() {
    if (_submitting) return;
    setState(() => _submitting = true);
    final pack = _packs[_packIdx];
    final cart = ref.read(cartControllerProvider.notifier);
    final free = _giveFree;

    // Вынос мусора — одна услуга: типы пакетов взаимоисключающие.
    // Сначала убираем все svc:trash:*, затем кладём выбранный.
    final items = ref.read(cartControllerProvider).items;
    for (final id in items.keys.toList()) {
      if (id.startsWith('svc:trash:')) cart.setQty(id, 0);
    }
    final baseId = 'svc:trash:${pack.id}';
    cart.add(CartProduct(
      id: free ? '$baseId:free' : baseId,
      name: free ? 'Вынос мусора · ${pack.label} (по купону)' : 'Вынос мусора · ${pack.label}',
      unit: pack.weight,
      price: free ? 0 : pack.price,
      kind: 'service',
      image: 'assets/trash-v2/helper-trash-${pack.id}.webp',
      service: CartServicePayload(kind: 'trash', details: {
        'packId': pack.id,
        'packs': pack.id,
        'label': pack.label,
        'weight': pack.weight,
        'unitPrice': pack.price,
        'when': 'asap',
        'pickup': 'door',
        'free': free,
      }),
    ));
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _submitting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    ref.watch(couponControllerProvider);
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';
    final pack = _packs[_packIdx];
    final giveFree = _giveFree;
    final trashInCart = cart.items.keys.any((id) => id.startsWith('svc:trash:'));

    return Scaffold(
      backgroundColor: BemColors.surface,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 160),
            children: [
              AddressTopBar(address: address, backFallback: '/home'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text('Вынос мусора',
                    style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w800,
                      letterSpacing: -0.8, height: 1.05, color: BemColors.ink,
                    )),
              ),
              // 2-колоночная сетка карточек пакетов — как на живом сайте.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.74,
                  children: [
                    for (var i = 0; i < _packs.length; i++)
                      _PackCard(
                        pack: _packs[i],
                        active: i == _packIdx,
                        flipped: _flippedIdx == i,
                        onSelect: () => setState(() => _packIdx = i),
                        onFlip: () => setState(() => _flippedIdx = i),
                        onUnflip: () => setState(() => _flippedIdx = null),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyCtaCapsule(
              show: true,
              title: _submitting
                  ? 'Добавлено'
                  : giveFree
                      ? 'Получить бесплатно'
                      : trashInCart
                          ? 'Изменить на этот'
                          : 'В корзину',
              subtitle: giveFree ? 'по купону' : (trashInCart ? 'заменит выбранный пакет' : 'время и передача — в корзине'),
              price: giveFree ? 0 : pack.price,
              onTap: _addPack,
              onCart: () => context.push('/cart'),
              cartCount: cart.totalQty,
              disabled: _submitting,
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка пакета с переворотом (3D rotateY) — лицо/спина.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.active,
    required this.flipped,
    required this.onSelect,
    required this.onFlip,
    required this.onUnflip,
  });

  final _Pack pack;
  final bool active;
  final bool flipped;
  final VoidCallback onSelect;
  final VoidCallback onFlip;
  final VoidCallback onUnflip;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: flipped ? 1 : 0),
      duration: const Duration(milliseconds: 480),
      curve: const Cubic(0.22, 0.68, 0.32, 1),
      builder: (context, t, _) {
        // В покое — без 3D-Transform (перспектива ломает hit-test → выбор
        // пакета/«?» не нажимались). Transform только во время анимации.
        if (t == 0) return _front();
        if (t == 1) return _back();
        final angle = t * math.pi; // 0..pi
        final showBack = t > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0011) // перспектива
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi), // развернуть спину лицом
                  child: _back(),
                )
              : _front(),
        );
      },
    );
  }

  Widget _front() {
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: active
              ? [BoxShadow(color: _accent.withValues(alpha: 0.31), blurRadius: 22, spreadRadius: -10, offset: const Offset(0, 8))]
              : const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
          border: active ? Border.all(color: _accent, width: 1.5) : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ярлык + подсказка (слева сверху, место под «?» справа).
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 40, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4,
                            height: 1, color: active ? _accent : BemColors.ink,
                          )),
                      const SizedBox(height: 3),
                      Text(pack.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BemColors.mute)),
                    ],
                  ),
                ),
                // 3D-помощник — занимает свободное место, прижат к низу.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Image.asset('assets/trash-v2/helper-trash-${pack.id}.webp', fit: BoxFit.contain),
                    ),
                  ),
                ),
                // Цена слева + вес справа.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${pack.price} ₽',
                          style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1,
                            color: active ? _accent : BemColors.ink,
                          )),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(pack.weight,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: BemColors.mute)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // «?» — переворот.
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onFlip,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFE8551F).withValues(alpha: 0.5), blurRadius: 10, spreadRadius: -3)],
                  ),
                  child: const Icon(Icons.question_mark, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _back() {
    return GestureDetector(
      onTap: onUnflip,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF6F2), Color(0xFFFFE7DC)],
          ),
          border: Border.all(color: _accent, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text('Как это работает',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _accent)),
                ),
                Container(
                  width: 26, height: 26,
                  decoration: const BoxDecoration(color: Color(0x0F000000), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: BemColors.mute),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Expanded(
              child: Text(
                'Оставьте пакет у двери — курьер заберёт и отнесёт на помойку. После первой доставки положим фирменные пакеты bembox в подарок.',
                style: TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF5C5048)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
