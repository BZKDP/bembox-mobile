import 'package:flutter/animation.dart';

/// Анимационные тайминги и кривые — извлечены 1:1 из CSS-анимаций сайта
/// (`apps/web/app/globals.css`, секции @keyframes / transition).
///
/// Цель — чтобы движения в приложении ощущались идентично сайту: те же
/// длительности (ms) и те же кубические кривые Безье.
///
/// Напоминание про cubic-bezier: CSS `cubic-bezier(x1,y1,x2,y2)` ↔
/// Flutter `Cubic(x1,y1,x2,y2)`.
abstract final class BemMotion {
  // ── Кривые ──
  /// «Пружинка» с лёгким перелётом — самая частая на сайте.
  /// CSS: cubic-bezier(0.34, 1.56, 0.64, 1). Используется в tab-icon-pop,
  /// cart-pop, cup-size-anim, cup-yscale.
  static const Cubic spring = Cubic(0.34, 1.56, 0.64, 1);

  /// Плавный «слайд» каруселей (кофе). CSS: cubic-bezier(.22,.9,.35,1.05).
  static const Cubic slide = Cubic(0.22, 0.9, 0.35, 1.05);

  /// Кривая слот-перехода чашек. CSS: cubic-bezier(.22,.9,.32,1) (cart-bump-card).
  static const Cubic bump = Cubic(0.22, 0.9, 0.32, 1);

  /// Стандартный ease-out для затуханий (opacity/filter).
  static const Cubic easeOut = Cubic(0.0, 0.0, 0.58, 1.0);

  // ── Длительности (мс из CSS) ──
  static const Duration tabIconPop = Duration(milliseconds: 420); // tab-icon-pop
  static const Duration cartPop = Duration(milliseconds: 360); // .cart-pop
  static const Duration cartBumpCard = Duration(milliseconds: 950); // .cart-bump-card
  static const Duration cupSlide = Duration(milliseconds: 540); // .cup-slide-track
  static const Duration cupSlot = Duration(milliseconds: 520); // .cup-slot
  static const Duration cupSize = Duration(milliseconds: 380); // .cup-size-anim

  /// Быстрый отклик кнопки (.btn active:translate-y-px) — короткое нажатие.
  static const Duration tap = Duration(milliseconds: 120);

  /// Базовый переход между состояниями (общий).
  static const Duration base = Duration(milliseconds: 250);
}
