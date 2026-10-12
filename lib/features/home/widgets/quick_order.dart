import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bem_colors.dart';
import 'time_pennant.dart';

/// Услуга для секции «Быстрый заказ» — данные 1:1 из массива SERVICES в QuickOrder.tsx.
class _Service {
  const _Service({
    required this.slug,
    required this.title,
    required this.desc,
    required this.minutes,
    required this.priceFrom,
    required this.img,
    required this.cardBg,
    required this.chipText,
    required this.imgScale,
    this.pvz = false,
  });

  final String slug;
  final String title;
  final String desc; // строки через \n
  final String minutes; // «15»
  final int priceFrom;
  final String img;
  final Color cardBg;
  final Color chipText;
  final double imgScale; // процент ширины карточки
  final bool pvz; // ПВЗ → футер «бесплатно»
}

const _services = <_Service>[
  _Service(slug: 'coffee', title: 'Кофе', desc: 'Сами сварим\nи привезём горячим', minutes: '15', priceFrom: 190, img: 'assets/illu-v5/coffee.webp', cardBg: Color(0xFFFDF3E5), chipText: Color(0xFF8A4F1A), imgScale: 60),
  _Service(slug: 'breakfast', title: 'Завтраки', desc: 'Сырники\nомлет\nкаша\nсэндвич', minutes: '15', priceFrom: 190, img: 'assets/illu-v5/breakfast.webp', cardBg: Color(0xFFFCE7E1), chipText: Color(0xFFC9544A), imgScale: 54),
  _Service(slug: 'products', title: 'Продукты', desc: 'Молоко\nхлеб\nяйца\nмясо', minutes: '15', priceFrom: 99, img: 'assets/illu-v5/grocery.webp', cardBg: Color(0xFFFCEBA8), chipText: Color(0xFFB5811A), imgScale: 52),
  _Service(slug: 'water', title: 'Чистая вода', desc: 'Доставим прямо\nдо двери', minutes: '10', priceFrom: 99, img: 'assets/illu-v5/water.webp', cardBg: Color(0xFFEEF3FD), chipText: Color(0xFF3D67BB), imgScale: 50),
  _Service(slug: 'trash', title: 'Вынос мусора', desc: 'Заберём\nот двери', minutes: '10', priceFrom: 49, img: 'assets/illu-v5/trash.webp', cardBg: Color(0xFFEAF4E1), chipText: Color(0xFF3A8F3A), imgScale: 50),
  _Service(slug: 'pvz', title: 'ПВЗ', desc: 'Заберём посылку\nиз пункта выдачи', minutes: '10', priceFrom: 100, img: 'assets/illu-v5/pvz.webp', cardBg: Color(0xFFEFEAFB), chipText: Color(0xFF7A5CD6), imgScale: 52, pvz: true),
];

/// Секция «Быстрый заказ» — порт `QuickOrder.tsx` 1:1.
/// (Купонный вариант футера-билета добавим вместе с системой купонов; сейчас —
/// дефолтный футер «от X ₽» / «бесплатно», как при отсутствии выданного купона.)
class QuickOrder extends StatelessWidget {
  const QuickOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Быстрый заказ',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: BemColors.ink,
                  )),
              const SizedBox(height: 4),
              Text('Соседи донесут — без звонков и ожидания',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BemColors.mute)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1 / 1.05,
          children: [for (final s in _services) _Card(s)],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.s);
  final _Service s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Реализованные экраны услуг ведём на них; остальные — пока заглушка.
        switch (s.slug) {
          case 'trash':
            context.push('/services/trash');
          case 'coffee':
            context.push('/services/coffee');
          case 'breakfast':
            context.push('/services/breakfast');
          case 'water':
            context.push('/services/water');
          case 'products':
            context.push('/services/products');
          case 'pvz':
            context.push('/pvz');
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Услуга «${s.title}» — скоро')),
            );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: s.cardBg,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: Color(0x47281E14), blurRadius: 30, spreadRadius: -16, offset: Offset(0, 14)),
          ],
        ),
        child: Column(
          children: [
            // Контент карточки (overlay, как на сайте): картинка абсолютно в
            // правом-нижнем углу, поверх — текст. Заголовок и вымпел в одном ряду
            // (не наедут). Описание ограничено по ширине слева. Stack не даёт
            // overflow-ошибки и совпадает со структурой сайта.
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final imgW = c.maxWidth * s.imgScale / 100;
                  return Stack(
                    children: [
                      // Иллюстрация — значения из QuickOrder.tsx.
                      if (s.slug == 'coffee')
                        Positioned(
                          right: 6, bottom: 10, width: imgW,
                          child: Image.asset(s.img, width: imgW, fit: BoxFit.fitWidth),
                        )
                      else
                        Positioned(
                          right: 6,
                          bottom: (s.slug == 'water' || s.slug == 'trash') ? 2 : 10,
                          width: imgW,
                          height: c.maxHeight * 0.6,
                          child: Image.asset(s.img, fit: BoxFit.contain),
                        ),
                      // Текст поверх.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Заголовок — всегда в ОДНУ строку (как на сайте).
                            // Отступ справа освобождает место под вымпел; FittedBox
                            // ужимает текст под доступную ширину, поэтому длинные
                            // названия («Вынос мусора», «Чистая вода») не переносятся
                            // и не обрезаются многоточием.
                            SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 46),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    s.title,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: const TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      height: 1.05,
                                      color: BemColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Описание держим слева (≈56% ширины), чтобы не лезло на картинку.
                            SizedBox(
                              width: c.maxWidth * 0.56,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final line in s.desc.split('\n'))
                                    Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.34,
                                        fontWeight: FontWeight.w600,
                                        color: BemColors.ink.withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Вымпел времени — абсолютно в правом-верхнем углу
                      // (не влияет на высоту строки заголовка → нет overflow).
                      Positioned(
                        top: 10,
                        right: 10,
                        child: TimePennant(minutes: s.minutes, color: s.chipText),
                      ),
                    ],
                  );
                },
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  /// Нижняя плашка-билет (дефолтный вид). plate = смесь фона карточки и цвета услуги.
  Widget _footer() {
    final plate = Color.lerp(s.cardBg, s.chipText, 0.2)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      height: 42,
      decoration: BoxDecoration(
        color: plate,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: s.chipText.withValues(alpha: 0.15)),
      ),
      alignment: Alignment.center,
      child: s.priceFrom == 0
          ? Text('бесплатно',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: s.chipText, height: 1))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('от ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BemColors.mute)),
                Text('${s.priceFrom}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BemColors.ink, height: 1)),
                Text(' ₽',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BemColors.ink.withValues(alpha: 0.6))),
              ],
            ),
    );
  }
}
