import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/bem_colors.dart';
import '../../data/models/cart_item.dart';
import 'widgets/address_top_bar.dart';
import 'widgets/sticky_cta_capsule.dart';

/// Блюдо завтрака — данные 1:1 из `lib/breakfasts.ts` (массив BREAKFASTS).
/// Картинка-карточка (название и «завтрак» уже впечатаны) лежит в assets/breakfast.
class _Breakfast {
  const _Breakfast(this.slug, this.name, this.sub, this.img, this.price, this.weight,
      this.p, this.f, this.c, this.kcal, this.composition);
  final String slug;
  final String name;
  final String sub; // уточнение под именем на детали
  final String img;
  final int price;
  final int weight; // граммовка порции
  final String p, f, c, kcal; // КБЖУ на порцию
  final String composition; // состав
}

const _breakfasts = <_Breakfast>[
  _Breakfast('porridge', 'Овсяная каша', 'На молоке', 'assets/breakfast/porridge.png', 200, 250,
      '1.6', '3.3', '10.5', '78.1',
      'Вода питьевая, молоко питьевое ультрапастеризованное массовая доля жира 3,2%, хлопья овсяные «геркулес», масло сливочное м.д.ж. 82,5%, сахар, соль пищевая.'),
  _Breakfast('omelette', 'Омлет', 'С томатами и моцареллой', 'assets/breakfast/omelette.png', 220, 200,
      '10.9', '10.1', '6.8', '161.7',
      'Масса омлетная (молоко питьевое м.д.ж. 3.2%, меланж яичный жидкий, крахмал картофельный, соль пищевая, стабилизатор — ксантановая камедь), томаты свежие, сыр моцарелла м.д.ж. в сухом веществе 40%, масло подсолнечное рафинированное дезодорированное.'),
  _Breakfast('syrniki', 'Сырники', 'Классические, жареные', 'assets/breakfast/syrniki.png', 298, 200,
      '1.6', '3.3', '10.5', '78.1',
      'Творог, мука пшеничная высшего сорта, яйцо куриное, сахар, масло подсолнечное рафинированное дезодорированное, соль пищевая.'),
  _Breakfast('ciabatta', 'Чиабатта', 'С курицей, сыром «Гауда» и соусом барбекю, 2 шт', 'assets/breakfast/ciabatta.png', 300, 300,
      '9.1', '6.2', '29', '208.2',
      'Чиабатта (мука пшеничная хлебопекарная высшего сорта, вода питьевая, оливки, масло подсолнечное рафинированное, сахар, крупа манная, дрожжи хлебопекарные, соль), филе куриной грудки запечённое, соус барбекю, томаты свежие, сыр Гауда м.д.ж. 45%, салат романо, огурцы солёные.'),
];

/// Нюдово-коралловая палитра (как `services/breakfast/page.tsx`).
const _pageBg = Color(0xFFFFFCF6);
const _addTile = Color(0xFFFFE9DF);
const _addIcon = Color(0xFFFF7547);

CartProduct _cartItem(_Breakfast b) => CartProduct(
      id: 'svc:breakfast:${b.slug}',
      name: b.name,
      unit: 'порция',
      price: b.price,
      kind: 'service',
      image: b.img,
      service: CartServicePayload(kind: 'breakfast', details: {
        'slug': b.slug,
        'label': b.name,
        'time': 'asap',
      }),
    );

/// Экран «Завтраки» — порт `app/services/breakfast/page.tsx` 1:1.
/// Сетка готовых карточек-блюд; тап по фото/цене → деталь, кнопка-корзинка
/// добавляет напрямую (со степпером количества).
class BreakfastScreen extends ConsumerWidget {
  const BreakfastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 160),
            children: [
              AddressTopBar(address: address, backFallback: '/home'),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text('Завтраки',
                    style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w800,
                      letterSpacing: -0.8, height: 1.05, color: BemColors.ink,
                    )),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  // квадратное фото + строка цены/кнопки снизу → соотношение ≈0.72.
                  childAspectRatio: 0.72,
                  children: [
                    for (final b in _breakfasts)
                      _Card(
                        b: b,
                        qty: cart.items['svc:breakfast:${b.slug}'] ?? 0,
                        onOpen: () => context.push('/services/breakfast/${b.slug}'),
                        onAdd: () {
                          ref.read(cartControllerProvider.notifier).add(_cartItem(b));
                          HapticFeedback.selectionClick();
                        },
                        onRemove: () => ref.read(cartControllerProvider.notifier).remove('svc:breakfast:${b.slug}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyCtaCapsule(
              show: cart.totalQty > 0,
              title: 'В корзину',
              subtitle: '${cart.totalQty} ${_plural(cart.totalQty, 'позиция', 'позиции', 'позиций')}',
              price: cart.totalPrice,
              onTap: () => context.push('/cart'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.b, required this.qty, required this.onOpen, required this.onAdd, required this.onRemove});
  final _Breakfast b;
  final int qty;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, spreadRadius: -6, offset: Offset(0, 2))],
        border: Border.all(color: const Color(0xFFEFE7D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Картинка-карточка (название впечатано) — тап ведёт на деталь.
          GestureDetector(
            onTap: onOpen,
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(b.img, fit: BoxFit.cover),
            ),
          ),
          // Цена (тап → деталь) слева + добавление справа.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onOpen,
                    behavior: HitTestBehavior.opaque,
                    child: Text('${b.price} ₽',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          letterSpacing: -0.3, color: BemColors.ink,
                        )),
                  ),
                ),
                if (qty > 0)
                  _Stepper(qty: qty, onAdd: onAdd, onRemove: onRemove)
                else
                  GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: _addTile, shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_cart_outlined, size: 17, color: _addIcon),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Коралловый степпер «− N +» (как на сайте при qty>0).
class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onAdd, required this.onRemove});
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFF7547), Color(0xFFE85522)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, onRemove),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text('$qty',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          _btn(Icons.add, onAdd),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 26, height: 28,
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      );
}

/// Деталь блюда — порт `app/services/breakfast/[slug]/page.tsx` 1:1.
/// Фото + имя/граммовка/цена + БЖУ (4 ячейки) + состав; нижний бар «Добавить».
class BreakfastDetailScreen extends ConsumerWidget {
  const BreakfastDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = _breakfasts.where((x) => x.slug == slug).firstOrNull;
    final cart = ref.watch(cartControllerProvider);
    final address = ref.watch(authControllerProvider).user?.lastAddress ?? '';

    if (b == null) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Такого завтрака нет', style: TextStyle(color: BemColors.mute)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go('/services/breakfast'), child: const Text('Назад')),
          ]),
        ),
      );
    }

    final kbju = [
      (v: b.p, l: 'белки'),
      (v: b.f, l: 'жиры'),
      (v: b.c, l: 'углеводы'),
      (v: b.kcal, l: 'ккал'),
    ];

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              AddressTopBar(address: address, backFallback: '/services/breakfast'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Картинка-карточка.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(b.img, fit: BoxFit.cover),
                      ),
                    ),
                    // Имя + граммовка/цена.
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.name,
                                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink)),
                                const SizedBox(height: 2),
                                Text(b.sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BemColors.mute)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${b.price} ₽',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: BemColors.ink)),
                              const SizedBox(height: 4),
                              Text('${b.weight} г',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: BemColors.mute)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Пищевая ценность — 4 ячейки.
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ПИЩЕВАЯ ЦЕННОСТЬ · ПОРЦИЯ ${b.weight} Г',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: BemColors.mute)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFFF4EFE2), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              children: [
                                for (var i = 0; i < kbju.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 6),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFEFE7D4)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(kbju[i].v,
                                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1, color: BemColors.ink)),
                                          const SizedBox(height: 4),
                                          Text(kbju[i].l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: BemColors.mute)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Состав.
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEFE7D4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('СОСТАВ',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: BemColors.mute)),
                            const SizedBox(height: 6),
                            Text(b.composition,
                                style: const TextStyle(fontSize: 13.5, height: 1.5, color: BemColors.ink2)),
                          ],
                        ),
                      ),
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
              title: 'Добавить',
              price: b.price,
              onTap: () {
                ref.read(cartControllerProvider.notifier).add(_cartItem(b));
                HapticFeedback.lightImpact();
              },
              onCart: () => context.push('/cart'),
              cartCount: cart.totalQty,
            ),
          ),
        ],
      ),
    );
  }
}

String _plural(int n, String one, String few, String many) {
  final m = n.abs() % 100;
  final m1 = m % 10;
  if (m > 10 && m < 20) return many;
  if (m1 > 1 && m1 < 5) return few;
  if (m1 == 1) return one;
  return many;
}
