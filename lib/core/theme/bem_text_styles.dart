import 'package:flutter/material.dart';
import 'bem_colors.dart';

/// Текстовые стили на основе Manrope — как на сайте.
///
/// На сайте глобально задано: `font-family: Manrope; letter-spacing: -0.005em;`
/// (globals.css). Веса, которые реально используются в верстке: 400/500/600/700/800.
///
/// `letterSpacing` в Flutter задаётся в логических пикселях, а в CSS `em` —
/// относительно размера шрифта. -0.005em ≈ небольшое поджатие; на размере 14
/// это ≈ -0.07px. Чтобы не зашивать на каждый размер, используем приблизительное
/// небольшое отрицательное значение и tightening через [tight].
abstract final class BemText {
  static const String family = 'Manrope';

  /// Глобальное лёгкое поджатие трекинга, как `letter-spacing:-0.005em` на сайте.
  static const double tight = -0.1;

  static const TextStyle _base = TextStyle(
    fontFamily: family,
    color: BemColors.ink,
    letterSpacing: tight,
    height: 1.25,
  );

  // Заголовки (display)
  static final TextStyle h1 = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w800);
  static final TextStyle h2 = _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static final TextStyle h3 = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);

  // Текст
  static final TextStyle body = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
  static final TextStyle bodyStrong = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static final TextStyle small = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500);

  /// Подписи/служебное — приглушённый цвет.
  static final TextStyle caption =
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: BemColors.mute);

  /// Текст кнопки `.btn` на сайте: 13.5px, font-semibold, tracking-tight.
  static final TextStyle button = _base.copyWith(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Цена — крупно и жирно (как ценники «у Озона»).
  static final TextStyle price = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w800);
}
