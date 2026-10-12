import 'package:flutter/material.dart';

/// Промо-баннер главной — как на ЖИВОМ сайте `https://bembox.ru` (одна картинка
/// `promo-15min.webp` «За 15 минут к двери», скруглённая, с мягкой тенью).
///
/// Раньше в репозитории была карусель из 4 слайдов promo-allfree — на проде её
/// заменили на единый баннер; берём прод как эталон.
class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          // TODO(промо): открыть PromoSheet с условиями — отдельный этап.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Условия акции — скоро')),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x61E5552F), blurRadius: 20, spreadRadius: -12, offset: Offset(0, 10)),
              ],
            ),
            child: Image.asset(
              'assets/promo/promo-15min.webp',
              fit: BoxFit.fitWidth,
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}
