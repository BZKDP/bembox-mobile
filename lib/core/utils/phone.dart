/// Работа с телефонными номерами — порт логики сайта 1:1.
///
/// Источники на сайте:
///   • `apps/web/lib/format-phone.ts`  — маска ввода и валидация.
///   • `apps/web/lib/server/auth-phone.ts` → normalizePhone — нормализация для API.
///
/// Важно держать идентично бэкенду: бэкенд хранит телефон как `+7XXXXXXXXXX`
/// и сам нормализует вход, но мы валидируем/маскируем так же, чтобы UX совпадал.
abstract final class Phone {
  /// Только цифры из произвольной строки.
  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D+'), '');

  /// Номер заполнен корректно (ровно 11 цифр РФ).
  static bool isValid(String raw) => digitsOnly(raw).length == 11;

  /// Нормализация для отправки на API: `+7XXXXXXXXXX` или null.
  /// Повторяет normalizePhone() с сервера: 8XXXXXXXXXX→7…, 10 цифр→+7…
  static String? normalize(String input) {
    var p = digitsOnly(input);
    if (p.length < 10) return null;
    if (p.length == 11 && p.startsWith('8')) p = '7${p.substring(1)}';
    if (p.length == 10) p = '7$p';
    if (p.length != 11) return null;
    return '+$p';
  }

  /// Маска ввода `+7 (XXX) XXX-XX-XX` — порт formatPhone() с сайта 1:1.
  static String format(String raw) {
    var d = digitsOnly(raw);
    if (d.length > 11) d = d.substring(0, 11);
    if (d.isEmpty) return '';
    var p = d;
    if (p.length == 11 && p.startsWith('8')) p = '7${p.substring(1)}';
    if (p.isNotEmpty && !p.startsWith('7')) {
      final tail = p.length > 10 ? p.substring(0, 10) : p;
      p = '7$tail';
    }
    var out = '+7';
    if (p.length > 1) out += ' (${p.substring(1, p.length < 4 ? p.length : 4)}';
    if (p.length >= 5) out += ') ${p.substring(4, p.length < 7 ? p.length : 7)}';
    if (p.length >= 8) out += '-${p.substring(7, p.length < 9 ? p.length : 9)}';
    if (p.length >= 10) out += '-${p.substring(9, p.length < 11 ? p.length : 11)}';
    return out;
  }
}
