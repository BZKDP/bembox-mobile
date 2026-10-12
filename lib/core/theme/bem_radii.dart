import 'package:flutter/widgets.dart';

/// Скругления углов — 1:1 с сайтом (`tailwind.config.ts` → `borderRadius`).
/// На сайте также активно используется `rounded-full` (пилюли/кнопки) → [full].
abstract final class BemRadii {
  static const double s = 12; // tailwind rounded-s
  static const double m = 14; // rounded-m
  static const double l = 18; // rounded-l
  static const double xl = 24; // rounded-xl
  static const double xl2 = 32; // rounded-2xl
  static const double full = 999; // rounded-full (кнопки .btn, пиллы)

  static const rS = BorderRadius.all(Radius.circular(s));
  static const rM = BorderRadius.all(Radius.circular(m));
  static const rL = BorderRadius.all(Radius.circular(l));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rXl2 = BorderRadius.all(Radius.circular(xl2));
  static const rFull = BorderRadius.all(Radius.circular(full));
}
