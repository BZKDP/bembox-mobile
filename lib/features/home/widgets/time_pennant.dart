import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Вымпел времени на карточке услуги — порт SVG `<TimePennant/>` из QuickOrder.tsx.
///
/// Геометрия 1:1: тот же path в системе координат viewBox 64×70, отрисованный
/// в боксе 44×48. Цвет = фирменный цвет услуги (chipText). Внутри — число минут
/// крупно и «МИН» мельче, белым; поверх — белый пунктир (прошитая строчка),
/// как на сайте.
class TimePennant extends StatelessWidget {
  const TimePennant({super.key, required this.minutes, required this.color});

  /// Число минут (например «15»).
  final String minutes;

  /// Цвет вымпела (chipText услуги).
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 48,
      child: CustomPaint(painter: _PennantPainter(minutes: minutes, color: color)),
    );
  }
}

class _PennantPainter extends CustomPainter {
  _PennantPainter({required this.minutes, required this.color});

  final String minutes;
  final Color color;

  // SVG path вымпела в координатах viewBox 64×70 (см. QuickOrder.tsx, переменная body).
  static final ui.Path _bodyVb = ui.Path()
    ..moveTo(11, 0)
    ..lineTo(49, 0)
    ..quadraticBezierTo(54, 0, 54, 5)
    ..lineTo(54, 51)
    ..quadraticBezierTo(54, 58, 47.5, 55.3)
    ..lineTo(30, 48)
    ..lineTo(12.5, 55.3)
    ..quadraticBezierTo(6, 58, 6, 51)
    ..lineTo(6, 5)
    ..quadraticBezierTo(6, 0, 11, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    // Масштаб из viewBox 64×70 в реальный размер (44×48).
    canvas.save();
    canvas.scale(size.width / 64.0, size.height / 70.0);

    // Тень: drop-shadow(3px 1px 3px color66).
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.40)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(3, 1);
    canvas.drawPath(_bodyVb, shadowPaint);
    canvas.restore();

    // Заливка фирменным цветом.
    canvas.drawPath(_bodyVb, Paint()..color = color);

    // Верхний светлый / нижний тёмный градиент-оверлей (объём).
    final overlay = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(30, 0),
        const Offset(30, 58),
        [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.14),
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawPath(_bodyVb, overlay);

    // Белый пунктир (прошитая строчка), масштаб 0.9 относительно центра (30,29).
    final stitchPath = _scaleAround(_bodyVb, 0.9, const Offset(30, 29));
    _drawDashed(
      canvas,
      stitchPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
      dash: 3.2,
      gap: 2.4,
    );

    // Текст: число (20) и «МИН» (10.5), белым. Центрируем по ЦЕНТРУ глифов
    // (а не по базовой линии) — иначе «15» уезжает вверх и выглядит криво.
    _text(canvas, minutes, 20, FontWeight.w800, const Offset(30, 19), letterSpacing: -1);
    _text(canvas, 'МИН', 10.5, FontWeight.w800, const Offset(30, 36), letterSpacing: 0.5);

    canvas.restore();
  }

  /// Текст, центрированный и по горизонтали, и по вертикали относительно [center].
  void _text(Canvas canvas, String s, double size, FontWeight weight, Offset center,
      {double letterSpacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Manrope',
          fontWeight: weight,
          fontSize: size,
          letterSpacing: letterSpacing,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  /// Масштабирование пути вокруг точки [center] на коэффициент [k].
  /// Матрица 4×4 в column-major порядке (как ждёт [ui.Path.transform]):
  ///   x' = k·x + (1−k)·cx,  y' = k·y + (1−k)·cy.
  ui.Path _scaleAround(ui.Path p, double k, Offset center) {
    final tx = (1 - k) * center.dx;
    final ty = (1 - k) * center.dy;
    final m = Float64List(16)
      ..[0] = k
      ..[5] = k
      ..[10] = 1
      ..[12] = tx
      ..[13] = ty
      ..[15] = 1;
    return p.transform(m);
  }

  /// Рисует путь пунктиром (dash/gap) — извлекаем сегменты через PathMetrics.
  void _drawDashed(Canvas canvas, ui.Path path, Paint paint,
      {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(
          metric.extractPath(dist, next.clamp(0, metric.length)),
          paint,
        );
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PennantPainter old) =>
      old.minutes != minutes || old.color != color;
}
