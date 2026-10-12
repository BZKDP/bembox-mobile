import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Лёгкий перехватчик ошибок: ловит ВСЕ необработанные исключения (Flutter-
/// фреймворк, асинхронные зоны, нативный канал) и складывает их в кольцевой
/// буфер последних крэшей. Сейчас sink — лог + буфер; когда подключим AppMetrica
/// (нужен ключ), добавим отправку телеметрии в [_report] одной строкой.
class CrashReporter {
  CrashReporter._();

  /// Последние крэши (для диагностики/будущей выгрузки на бэкенд).
  static final Queue<String> recent = Queue<String>();
  static const _maxRecent = 20;

  /// Подключить глобальные обработчики. Вызывать ВНУТРИ runZonedGuarded в main,
  /// после WidgetsFlutterBinding.ensureInitialized().
  static void install() {
    // Ошибки Flutter-фреймворка (build/layout/paint и т.п.).
    final prev = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      prev?.call(details);
      record(details.exception, details.stack, source: 'flutter');
    };

    // Ошибки нативного слоя/движка вне зоны Dart.
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      record(error, stack, source: 'platform');
      return true; // обработали — не роняем процесс.
    };
  }

  /// Зафиксировать ошибку. Можно передавать в runZonedGuarded напрямую.
  static void record(Object error, StackTrace? stack, {String source = 'zone'}) {
    final line = '[$source] $error';
    recent.addLast(line);
    while (recent.length > _maxRecent) {
      recent.removeFirst();
    }
    if (kDebugMode) {
      debugPrint('bembox crash $line');
      if (stack != null) debugPrint(stack.toString());
    }
    _report(error, stack, source);
  }

  /// Точка расширения для телеметрии (AppMetrica/Sentry/бэкенд). Пока no-op.
  static void _report(Object error, StackTrace? stack, String source) {
    // TODO(appmetrica): AppMetrica.reportError(message: '$source: $error', ...)
  }
}
