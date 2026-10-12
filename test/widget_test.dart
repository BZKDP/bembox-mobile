// Unit-тесты утилит, которые должны вести себя 1:1 с бэкендом/сайтом.
import 'package:flutter_test/flutter_test.dart';
import 'package:bembox/core/utils/phone.dart';
import 'package:bembox/core/utils/money.dart';

void main() {
  group('Phone.normalize — как normalizePhone на сервере', () {
    test('8XXXXXXXXXX → +7XXXXXXXXXX', () {
      expect(Phone.normalize('89000000000'), '+79000000000');
    });
    test('10 цифр → +7…', () {
      expect(Phone.normalize('9000000000'), '+79000000000');
    });
    test('+7 с разделителями', () {
      expect(Phone.normalize('+7 (900) 000-00-00'), '+79000000000');
    });
    test('короткий номер → null', () {
      expect(Phone.normalize('123'), isNull);
    });
  });

  group('Phone.isValid', () {
    test('11 цифр — валидно', () => expect(Phone.isValid('89622558057'), isTrue));
    test('меньше — нет', () => expect(Phone.isValid('8962255'), isFalse));
  });

  group('Money — рубли vs копейки (1:1 с сайтом: NBSP, без группировки)', () {
    const nbsp = ' ';
    test('рубли как есть', () {
      expect(Money.rub(190), '190$nbsp₽');
      expect(Money.rub(1290), '1290$nbsp₽');
    });
    test('копейки → рубли', () {
      expect(Money.fromKop(19000), '190$nbsp₽');
    });
    test('копейки с дробной частью', () {
      expect(Money.fromKopExact(19050), '190,50$nbsp₽');
    });
  });
}
