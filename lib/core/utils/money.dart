/// Работа с деньгами bembox.
///
/// ⚠️ КРИТИЧЕСКИ ВАЖНО — на бэкенде деньги в РАЗНЫХ единицах (см. schema.ts):
///   • `price` / `total` / `items_total` / `delivery_fee` — РУБЛИ целыми (int).
///   • `wallet_balance`, поля `*_kop` (wallet_paid_kop, card_paid_kop, amount_kop)
///     — КОПЕЙКИ (int).
///   • `bonus_balance` — РУБЛИ целыми.
///
/// Формат отображения — 1:1 с сайтом: число БЕЗ группировки тысяч + неразрывный
/// пробел + «₽» (на сайте `{price}&nbsp;₽`, напр. ProductCardV2.tsx). Поэтому
/// здесь НЕТ разделителя тысяч — иначе разойдёмся с сайтом.
abstract final class Money {
  /// Неразрывный пробел (U+00A0) — как `&nbsp;` на сайте между числом и ₽.
  static const String _nbsp = ' ';

  /// Сумма в РУБЛЯХ (price/total/bonus). Пример: 190 → «190 ₽».
  static String rub(int rubles) => '$rubles$_nbsp₽';

  /// Сумма в КОПЕЙКАХ (wallet/*_kop), округление вниз до рубля. 19000 → «190 ₽».
  static String fromKop(int kop) => rub(kop ~/ 100);

  /// Копейки с дробной частью, если она есть. 19050 → «190,50 ₽», 19000 → «190 ₽».
  static String fromKopExact(int kop) {
    final rubles = kop ~/ 100;
    final cents = kop.abs() % 100;
    if (cents == 0) return rub(rubles);
    return '$rubles,${cents.toString().padLeft(2, '0')}$_nbsp₽';
  }

  /// Рубли → копейки (для отправки на бэкенд, где он ждёт копейки).
  static int rubToKop(int rubles) => rubles * 100;

  /// Копейки → рубли (целочисленно).
  static int kopToRub(int kop) => kop ~/ 100;
}
