import 'package:flutter/material.dart';

/// Палитра бренда bembox — значения скопированы 1:1 из сайта
/// (`apps/web/tailwind.config.ts` и `apps/web/app/globals.css`, CSS-переменные `:root`).
///
/// ВАЖНО: цвета должны совпадать с сайтом до байта — приложение и сайт обязаны
/// выглядеть одинаково. При любом изменении токенов на сайте — синхронизировать здесь.
abstract final class BemColors {
  // ── Фирменный коралловый (акцент, кнопки, активные состояния) ──
  /// Основной бренд-цвет. tailwind: `coral.DEFAULT`, css: `--coral`.
  static const coral = Color(0xFFFF7547);

  /// Тёмно-коралловый (текст на светло-коралловом фоне). `coral.deep` / `--coral-deep`.
  static const coralDeep = Color(0xFF6B1E0A);

  /// Светло-коралловый фон (бейджи, подложки). `coral.soft` / `--coral-soft`.
  static const coralSoft = Color(0xFFFFE6DA);

  /// Средний коралловый (градиенты, иллюстрации). `coral.mid` / `--coral-mid`.
  static const coralMid = Color(0xFFFFB69A);

  // ── Фоны ──
  /// Кремовый фон (вариант body[data-variant="cream"]). `cream` / `--bg-cream`.
  static const cream = Color(0xFFFFF7F0);

  /// Белая поверхность (карточки, основной фон). `--bg-surface`.
  static const surface = Color(0xFFFFFFFF);

  /// Мягкий серый фон (поля ввода, пиллы). `--bg-soft`.
  static const soft = Color(0xFFF4F4F4);

  // ── Текст ──
  /// Основной тёмный текст. `ink.DEFAULT` / `--ink`.
  static const ink = Color(0xFF1A1410);

  /// Вторичный текст (подписи). `ink.2` / `--ink-2`.
  static const ink2 = Color(0xFF5C5048);

  /// Приглушённый текст / плейсхолдеры. `mute` / `--mute`.
  static const mute = Color(0xFF9C8E84);

  // ── Линии / разделители ──
  /// Цвет границ и разделителей. На сайте есть два значения:
  /// tailwind `line:#F0E6DC` и css `--line:#ECECEC`. В UI чаще используется
  /// css-переменная, поэтому базовый — ECECEC, а тёплый вариант — [lineWarm].
  static const line = Color(0xFFECECEC);
  static const lineWarm = Color(0xFFF0E6DC);

  // ── Статусы заказа (бейджи) — из globals.css .badge-* (Tailwind-палитра) ──
  static const badgeCreatedBg = Color(0xFFDBEAFE); // blue-100
  static const badgeCreatedFg = Color(0xFF1E40AF); // blue-800
  static const badgePaidBg = Color(0xFFD1FAE5); // emerald-100
  static const badgePaidFg = Color(0xFF065F46); // emerald-800
  static const badgePickingBg = Color(0xFFFEF3C7); // amber-100
  static const badgePickingFg = Color(0xFF92400E); // amber-800
  static const badgeDeliveringBg = Color(0xFFE0E7FF); // indigo-100
  static const badgeDeliveringFg = Color(0xFF3730A3); // indigo-800
  static const badgeDeliveredBg = Color(0xFFF4F4F5); // zinc-100
  static const badgeDeliveredFg = Color(0xFF3F3F46); // zinc-700
  static const badgeCancelledBg = Color(0xFFFEE2E2); // red-100
  static const badgeCancelledFg = Color(0xFF991B1B); // red-800
}
