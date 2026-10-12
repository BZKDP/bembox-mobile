import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/cart_item.dart';
import '../coupons/coupon_store.dart';
import 'widgets/sticky_cta_capsule.dart';

/// Напиток — данные из репо `CoffeeView2.tsx`, состав напитков как на проде
/// (3 типа: Латте/Капучино/Американо; «Раф» на проде убран).
class _Drink {
  const _Drink(this.slug, this.name, this.desc, this.base, this.make, this.p, this.f, this.c, this.kcal);
  final String slug;
  final String name;
  final String desc;
  final int base; // базовая цена (для размера S)
  final String make; // состав
  final String p, f, c, kcal; // КБЖУ на 100 г
}

const _drinks = <_Drink>[
  _Drink('latte', 'Латте', 'мягкий, на молоке', 220, 'Двойной эспрессо и молоко 3,2%.', '3,1', '3,0', '4,8', '54'),
  _Drink('cappuccino', 'Капучино', 'плотная пена, эспрессо', 220, 'Эспрессо, молоко и плотная молочная пена.', '3,3', '2,5', '4,5', '46'),
  _Drink('americano', 'Американо', 'чёрный, крепкий', 190, 'Двойной эспрессо и горячая вода.', '0,1', '0', '0,3', '2'),
];

/// Размер — S/M/L (решение встречи 13.05.2026). mult/addon формируют цену.
class _SizeConf {
  const _SizeConf(this.id, this.ml, this.mult, this.addon, this.scaleY);
  final String id;
  final String ml;
  final double mult;
  final int addon;
  final double scaleY; // вертикальный масштаб стакана в герое
}

const _sizes = <_SizeConf>[
  _SizeConf('S', '300 мл', 1.0, 0, 0.86),
  _SizeConf('M', '400 мл', 1.2, 0, 1.0),
  _SizeConf('L', '550 мл', 1.35, 40, 1.18),
];

const _soft = Color(0xFFF4F4F4);

/// Экран «Кофе» — порт `app/services/coffee/v2` + сверен с ЖИВЫМ сайтом.
class CoffeeScreen extends ConsumerStatefulWidget {
  const CoffeeScreen({super.key});

  @override
  ConsumerState<CoffeeScreen> createState() => _CoffeeScreenState();
}

class _CoffeeScreenState extends ConsumerState<CoffeeScreen> {
  int _drinkIdx = 0;
  String? _size; // null пока не выбран
  bool _composOpen = false;

  _Drink get _drink => _drinks[_drinkIdx];
  _SizeConf? get _sizeConf => _size == null ? null : _sizes.firstWhere((s) => s.id == _size);

  /// Цена: round(base*mult/10)*10 + addon (как на сайте).
  int get _price {
    final sc = _sizeConf;
    if (sc == null) return 0;
    return (_drink.base * sc.mult / 10).round() * 10 + sc.addon;
  }

  void _selectDrink(int idx) {
    final wrapped = (idx % _drinks.length + _drinks.length) % _drinks.length;
    if (wrapped == _drinkIdx) return;
    setState(() => _drinkIdx = wrapped);
    HapticFeedback.selectionClick();
  }

  /// Дать бесплатно: есть купон first-coffee И в корзине ещё нет бесплатного
  /// кофе (купон не стакается — босс 2026-06-02).
  bool get _giveFree {
    final hasCoupon = ref.read(couponControllerProvider.notifier).effectiveFor('coffee') != null;
    final cart = ref.read(cartControllerProvider);
    final hasFreeInCart = cart.items.keys.any((id) => id.startsWith('svc:coffee:') && id.endsWith(':free'));
    return hasCoupon && !hasFreeInCart;
  }

  void _addToCart() {
    final sc = _sizeConf;
    if (sc == null) return;
    final free = _giveFree;
    final baseId = 'svc:coffee:${_drink.slug}:$_size:asap';
    ref.read(cartControllerProvider.notifier).add(CartProduct(
          id: free ? '$baseId:free' : baseId,
          name: free ? '${_drink.name} · $_size (по купону)' : '${_drink.name} · $_size',
          unit: sc.ml,
          price: free ? 0 : _price,
          kind: 'service',
          image: 'assets/coffee/cup-${_drink.slug}.webp',
          service: CartServicePayload(kind: 'coffee', details: {
            'drink': _drink.slug,
            'size': _size,
            'time': 'asap',
            'free': free,
          }),
        ));
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    ref.watch(couponControllerProvider); // перерисовка при гашении купона
    final canOrder = _size != null;
    final giveFree = _giveFree;

    return Scaffold(
      backgroundColor: BemColors.surface,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              _hero(context),
              _titleSection(),
              _sizeSection(),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyCtaCapsule(
              show: canOrder,
              title: giveFree ? 'Получить бесплатно' : 'В корзину',
              price: giveFree ? 0 : _price,
              onTap: _addToCart,
              onCart: () => context.push('/cart'),
              cartCount: cart.totalQty,
            ),
          ),
        ],
      ),
    );
  }

  /// HERO — квадратная сцена (scene-bg), стакан по центру снизу (свайпом меняем
  /// напиток), снизу — стеклянные чипы выбора типа.
  Widget _hero(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -150) _selectDrink(_drinkIdx + 1);
          if (v > 150) _selectDrink(_drinkIdx - 1);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/coffee/scene-bg.webp', fit: BoxFit.cover),
            // Стакан (с анимацией смены и масштабом по размеру).
            Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: Align(
                alignment: Alignment.bottomCenter,
                // На смену НАПИТКА — кросс-слайд (ключ по slug). На смену
                // РАЗМЕРА — плавный scaleY (TweenAnimationBuilder сам анимирует
                // от текущего значения к новому `end`, как .cup-yscale на сайте:
                // 420ms, пружинистая кривая).
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: const Cubic(0.22, 0.68, 0.32, 1),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.18, 0), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_drink.slug),
                    tween: Tween<double>(end: _sizeConf?.scaleY ?? 1.0),
                    duration: const Duration(milliseconds: 420),
                    curve: const Cubic(0.34, 1.56, 0.64, 1),
                    builder: (context, sy, child) => Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(1, sy, 1),
                      child: child,
                    ),
                    child: Image.asset('assets/coffee/cup-${_drink.slug}.webp', height: 200, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            // Кнопка «назад» (стекло).
            Positioned(
              top: 12 + MediaQuery.of(context).padding.top,
              left: 12,
              child: GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_left, size: 22, color: BemColors.ink),
                ),
              ),
            ),
            // Чипы выбора напитка.
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _drinks.length; i++) _chip(i),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(int i) {
    final active = i == _drinkIdx;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _selectDrink(i),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.34 : 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: active ? 0.7 : 0.45)),
            boxShadow: const [BoxShadow(color: Color(0x66281A0A), blurRadius: 16, spreadRadius: -8, offset: Offset(0, 5))],
          ),
          child: Text(
            _drinks[i].name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: active ? BemColors.coral : Colors.white,
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }

  /// Название + цена + раскрываемый состав/КБЖУ.
  Widget _titleSection() {
    final sc = _sizeConf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_drink.name,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1)),
              const Spacer(),
              if (sc != null)
                Text('$_price ₽',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: BemColors.ink)),
            ],
          ),
          const SizedBox(height: 6),
          // Подпись + шеврон (раскрывает состав).
          GestureDetector(
            onTap: () => setState(() => _composOpen = !_composOpen),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_drink.desc}${sc != null ? ' · ${sc.ml}' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: BemColors.mute)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _composOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down, size: 16, color: BemColors.mute),
                ),
              ],
            ),
          ),
          // Раскрывающийся состав + КБЖУ.
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _composition(),
            crossFadeState: _composOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _composition() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_drink.make, style: TextStyle(fontSize: 13, height: 1.3, color: BemColors.ink.withValues(alpha: 0.8))),
            const SizedBox(height: 12),
            const Text('ПИЩЕВАЯ ЦЕННОСТЬ НА 100 Г',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: BemColors.mute)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6E1D7)),
              ),
              child: Row(
                children: [
                  _kbju('белки', _drink.p, false),
                  _kbju('жиры', _drink.f, true),
                  _kbju('углеводы', _drink.c, true),
                  _kbju('ккал', _drink.kcal, true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kbju(String label, String val, bool divider) {
    return Expanded(
      child: Container(
        decoration: divider
            ? const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFEDE8DF))))
            : null,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BemColors.ink, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, color: BemColors.mute)),
          ],
        ),
      ),
    );
  }

  /// Размеры S/M/L.
  Widget _sizeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('РАЗМЕР',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: BemColors.mute)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _sizes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _sizeBtn(_sizes[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizeBtn(_SizeConf s) {
    final active = _size == s.id;
    return GestureDetector(
      onTap: () => setState(() => _size = s.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white : _soft,
          borderRadius: BorderRadius.circular(14),
          border: active ? Border.all(color: BemColors.coral, width: 1.5) : null,
          boxShadow: active
              ? [BoxShadow(color: BemColors.coral.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: -6, offset: const Offset(0, 6))]
              : null,
        ),
        child: Column(
          children: [
            Text(s.id,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1, color: active ? BemColors.coral : BemColors.ink)),
            const SizedBox(height: 4),
            Text(s.ml, style: TextStyle(fontSize: 10.5, color: active ? BemColors.coralDeep.withValues(alpha: 0.6) : BemColors.mute)),
          ],
        ),
      ),
    );
  }
}
