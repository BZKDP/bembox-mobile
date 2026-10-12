import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/bem_colors.dart';
import '../../address/map_sheet.dart';

/// Герой главной — порт `HomeHero` (вариант v2) из
/// `apps/web/components/HomeHero.tsx` 1:1.
///
/// Бежевый контейнер (#F4F2EE, rounded-24) c адрес-баром сверху, маскотом справа,
/// белым «чат-пузырём» (приветствие жирным + подсказка) и полем «Ответить Бему…».
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final greeting = _greeting(user?.name);
    final hook = _hookV2();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2EE),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AddressBar(address: user?.lastAddress, onTap: () => showAddressMapSheet(context, ref)),
          // Маскот + чат-пузырь в общем стеке.
          SizedBox(
            height: 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -12,
                  top: -10,
                  child: Image.asset('assets/home/hero-mascot.webp', width: 166),
                ),
                // Белый пузырь: приветствие жирным + подсказка. maxWidth 62%.
                Align(
                  alignment: Alignment.topLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    child: Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 10,
                            spreadRadius: -4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: BemColors.ink,
                          ),
                          children: [
                            TextSpan(
                              text: greeting,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(text: ' $hook'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Поле «Ответить Бему…» — белый pill 66% ширины с круглой кнопкой.
          const _AssistantInput(),
        ],
      ),
    );
  }

  /// greetWord(h) из HomeHero.tsx.
  String _greeting(String? name) {
    final h = DateTime.now().hour;
    final word = h >= 5 && h < 12
        ? 'Доброе утро'
        : h >= 12 && h < 18
            ? 'Добрый день'
            : h >= 18 && h < 23
                ? 'Добрый вечер'
                : 'Доброй ночи';
    final first = (name != null && name.trim().isNotEmpty)
        ? ', ${name.trim().split(RegExp(r"\s+")).first}'
        : '';
    return '$word$first!';
  }

  /// Тексты приветствия по времени суток — выверены по ЖИВОМУ сайту
  /// (день: «Бем тут. Соберу корзину или вынесу мусор — без звонков.»).
  String _hookV2() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Бем тут. Кофе, вода, продукты — без звонков.';
    if (h >= 12 && h < 18) return 'Бем тут. Соберу корзину или вынесу мусор — без звонков.';
    if (h >= 18 && h < 23) return 'Вечер. Воду или ужин донесут из соседнего подъезда.';
    return 'Ночью на связи. Вода и аптека — донесут к двери.';
  }
}

/// Адрес-бар: пин + текст + шеврон. Пустой адрес — коралловый «Выберите адрес».
class _AddressBar extends StatelessWidget {
  const _AddressBar({this.address, this.onTap});
  final String? address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEmpty = address == null || address!.isEmpty;
    final color = isEmpty ? BemColors.coral : BemColors.ink;
    final title = isEmpty ? 'Выберите адрес' : address!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: isEmpty ? BemColors.coral : BemColors.ink2),
          ],
        ),
      ),
    );
  }
}

/// Поле «Ответить Бему…» — ведёт в AI-помощника (экран будет позже).
class _AssistantInput extends StatelessWidget {
  const _AssistantInput();

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.66,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 14, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0x1F000000), blurRadius: 10, spreadRadius: -4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Ответить Бему…',
                style: TextStyle(fontSize: 12, color: BemColors.mute),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: Color(0xFFEAE7E2), shape: BoxShape.circle),
              child: const Icon(Icons.send, size: 12, color: Color(0xFF8A8077)),
            ),
          ],
        ),
      ),
    );
  }
}
