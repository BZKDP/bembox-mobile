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

/// Вид воды — данные 1:1 из `VENDOR_PACKS` в `services/water/page.tsx`.
class _Pack {
  const _Pack(this.id, this.label, this.sub, this.price, this.kind, this.img, this.info);
  final String id;
  final String label;
  final String sub;
  final int price;
  final String kind; // pure | mineral
  final String img;
  final String info;
}

const _packs = <_Pack>[
  // Картинки — готовые сцены на всю карточку (v9 с прода): бутыль уже впечатана.
  _Pack('pure-5', 'Очищенная', '5 л', 99, 'pure', 'assets/water/pure-meadow.webp',
      'Набираем из автомата «Живая вода» в Трёхгорке. Проходит механическую и угольную очистку + обратный осмос. Мягкая, без лишних минералов — идеальна для чая, кофе и детей.'),
  _Pack('mineral-5', 'Минеральная', '5 л', 119, 'mineral', 'assets/water/mineral-mountain.webp',
      'Та же «Живая вода», но с добавлением сбалансированного минерального комплекса и озонированием. Приятный вкус, поддерживает баланс минералов. Набираем при вас, привозим свежей.'),
];

/// Лимит — максимум 2 бутыли за заказ (как на сайте, WATER_MAX).
const _waterMax = 2;
const _pageBg = Color(0xFFFBFAF7);

/// Экран «Вода» — порт `app/services/water/page.tsx`, сверен с ЖИВЫМ bembox.ru.
/// Стеклянная карточка с фоном-лугом (meadow.svg), бутыль по центру, сегментный
/// переключатель Очищенная/Минеральная (коралловый pill), «?» переворачивает
/// карточку к описанию. Нижний бар — единый StickyCtaCapsule, лимит 2 бутыли.
class WaterScreen extends ConsumerStatefulWidget {
  const WaterScreen({super.key});

  @override
  ConsumerState<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends ConsumerState<WaterScreen> {
  int _idx = 0;
  bool _flipped = false;
  String? _error;

  _Pack get _cur => _packs[_idx];

  int _waterQtyInCart(Map<String, int> items) =>
      items.entries.where((e) => e.key.startsWith('svc:water:')).fold(0, (s, e) => s + e.value);

  /// Купон first-water активен и в корзине ещё нет бесплатной воды.
  bool get _giveFree {
    final hasCoupon = ref.read(couponControllerProvider.notifier).effectiveFor('water') != null;
    final items = ref.read(cartControllerProvider).items;
    final hasFreeInCart = items.keys.any((id) => id.startsWith('svc:water:') && id.endsWith(':free'));
    return hasCoupon && !hasFreeInCart;
  }

  void _add() {
    final items = ref.read(cartControllerProvider).items;
    final free = _giveFree;
    // Бесплатная (по купону) бутыль не считается в лимит платных.
    if (!free && _waterQtyInCart(items) >= _waterMax) {
      setState(() => _error = 'Максимум 2 бутыли за заказ — больше не привезём за раз');
      return;
    }
    setState(() => _error = null);
    final baseId = 'svc:water:${_cur.id}';
    ref.read(cartControllerProvider.notifier).add(CartProduct(
          id: free ? '$baseId:free' : baseId,
          name: free ? '${_cur.label} вода · ${_cur.sub} (по купону)' : '${_cur.label} вода · ${_cur.sub}',
          unit: _cur.sub,
          price: free ? 0 : _cur.price,
          kind: 'service',
          image: _cur.img,
          service: CartServicePayload(kind: 'water', details: {
            'packId': _cur.id,
            'label': _cur.label,
            'handoff': 'door',
            'leaveAtDoor': true,
            'when': 'asap',
            'free': free,
          }),
        ));
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    ref.watch(couponControllerProvider);
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';
    final giveFree = _giveFree;
    final atLimit = _waterQtyInCart(cart.items) >= _waterMax;

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              AddressTopBar(address: address, backFallback: '/home'),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 18),
                child: Text('Вода на дом',
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, height: 1.12, color: BemColors.ink,
                    )),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final h = c.maxWidth * 1.34; // пропорция карточки сайта (≈358×480)
                    return SizedBox(height: h, child: _flipCard());
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFF9F1239))),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyCtaCapsule(
              show: true,
              title: giveFree ? 'Получить бесплатно' : (atLimit ? 'Уже 2 бутыли — максимум' : 'В корзину'),
              subtitle: giveFree ? 'по купону' : (atLimit ? 'больше не привезём за раз' : '${_cur.label} · ${_cur.sub}'),
              price: giveFree ? 0 : _cur.price,
              onTap: _add,
              onCart: () => context.push('/cart'),
              cartCount: cart.totalQty,
              disabled: atLimit && !giveFree,
            ),
          ),
        ],
      ),
    );
  }

  /// Переворот карточки лицо↔оборот (3D rotateY), как на сайте (600мс).
  Widget _flipCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _flipped ? 1 : 0),
      duration: const Duration(milliseconds: 600),
      curve: const Cubic(0.4, 0.1, 0.2, 1),
      builder: (context, t, _) {
        // В покое (t=0 лицо, t=1 оборот) рендерим БЕЗ 3D-Transform —
        // иначе перспектива ломает hit-test и тапы по сегменту/«?» не проходят.
        if (t == 0) return _front();
        if (t == 1) return _back();
        final angle = t * math.pi;
        final showBack = t > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0009)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _back(),
                )
              : _front(),
        );
      },
    );
  }

  Widget _front() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Color(0x38281E14), blurRadius: 30, spreadRadius: -16, offset: Offset(0, 16))],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Готовая сцена на всю карточку (бутыль впечатана) — плавная смена
            // при переключении Очищенная↔Минеральная.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: SizedBox.expand(
                key: ValueKey(_cur.id),
                child: Image.asset(_cur.img, fit: BoxFit.cover),
              ),
            ),
            // Заголовок текущей воды (поверх, белым с тенью).
            Positioned(
              left: 16, top: 16, right: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_cur.label,
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1,
                        color: Colors.white,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1))],
                      )),
                  const SizedBox(height: 6),
                  Text(_cur.sub,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1))],
                      )),
                ],
              ),
            ),
            // «?» — переворот карточки.
            Positioned(
              top: 12, right: 12,
              child: GestureDetector(
                onTap: () => setState(() => _flipped = true),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x14000000)),
                    boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8, spreadRadius: -4)],
                  ),
                  alignment: Alignment.center,
                  child: const Text('?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BemColors.ink)),
                ),
              ),
            ),
            // Сегментный переключатель Очищенная/Минеральная (тёмное стекло,
            // скользящий коралловый pill — как на живом сайте).
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: _segmented(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x73242018), // rgba(36,32,28,0.45)
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 22, spreadRadius: -10, offset: Offset(0, 8))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final pillW = (c.maxWidth - 0) / 2;
          return Stack(
            children: [
              // Скользящий коралловый индикатор активного.
              AnimatedAlign(
                alignment: _idx == 0 ? Alignment.centerLeft : Alignment.centerRight,
                duration: const Duration(milliseconds: 280),
                curve: const Cubic(0.22, 0.8, 0.32, 1),
                child: Container(
                  width: pillW,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF7547), Color(0xFFE85522)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [BoxShadow(color: Color(0x73E8551F), blurRadius: 16, spreadRadius: -6, offset: Offset(0, 6))],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _packs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (i == _idx) return;
                          setState(() => _idx = i);
                          HapticFeedback.selectionClick();
                        },
                        child: Center(
                          child: Text(_packs[i].label,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.2,
                                color: i == _idx ? Colors.white : Colors.white.withValues(alpha: 0.70),
                              )),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _back() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: const [BoxShadow(color: Color(0x38281E14), blurRadius: 30, spreadRadius: -16, offset: Offset(0, 16))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_cur.label,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink)),
              GestureDetector(
                onTap: () => setState(() => _flipped = false),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x1A000000)),
                  ),
                  child: const Icon(Icons.close, size: 18, color: BemColors.mute),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(_cur.info,
                  style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, color: BemColors.ink2)),
            ),
          ),
        ],
      ),
    );
  }
}
