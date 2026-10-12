import 'package:flutter/material.dart';
import 'bem_colors.dart';
import 'bem_radii.dart';
import 'bem_text_styles.dart';

/// Сборка [ThemeData] приложения из бренд-токенов bembox.
///
/// Цель — задать дефолты так, чтобы стандартные виджеты Flutter сразу выглядели
/// «по-bembox» (шрифт Manrope, коралловый акцент, скругления, цвета фона),
/// и дальше в экранах меньше переопределять вручную.
abstract final class BemTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BemColors.coral,
      primary: BemColors.coral,
      onPrimary: Colors.white,
      surface: BemColors.surface,
      onSurface: BemColors.ink,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BemColors.surface,
      fontFamily: BemText.family,
      // Убираем «чернильную» рябь Material по умолчанию — на сайте тап без волны,
      // активные состояния это лёгкий сдвиг/изменение фона.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),

      appBarTheme: const AppBarTheme(
        backgroundColor: BemColors.surface,
        foregroundColor: BemColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      // Поля ввода: мягкий серый фон, скругление m, без жирной рамки — как .pill-soft.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BemColors.soft,
        hintStyle: BemText.body.copyWith(color: BemColors.mute),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: BemRadii.rM,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BemRadii.rM,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BemRadii.rM,
          borderSide: BorderSide(color: BemColors.coral, width: 1.5),
        ),
      ),

      // Основная кнопка `.btn-coral`: коралловая, белый текст, rounded-full.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BemColors.coral,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: BemRadii.rFull),
          textStyle: BemText.button,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: BemColors.line,
        thickness: 1,
        space: 1,
      ),

      // Bottom-sheet'ы (на сайте — TimeSheet/MapSheet/PhoneSheet и т.п.): белый
      // фон, крупное верхнее скругление xl2.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BemColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(BemRadii.xl2)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: BemText.h1,
      headlineMedium: BemText.h2,
      headlineSmall: BemText.h3,
      titleLarge: BemText.h3,
      bodyLarge: BemText.body,
      bodyMedium: BemText.body,
      bodySmall: BemText.small,
      labelLarge: BemText.button,
      labelSmall: BemText.caption,
    );
  }
}
