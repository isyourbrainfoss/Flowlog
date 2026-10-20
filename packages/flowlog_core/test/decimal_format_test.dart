import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('decimalSeparatorForLocale', () {
    test('comma locales', () {
      expect(decimalSeparatorForLocale('nb'), ',');
      expect(decimalSeparatorForLocale('nb_NO'), ',');
      expect(decimalSeparatorForLocale('nb_NO.UTF-8'), ',');
      expect(decimalSeparatorForLocale('de-DE'), ',');
      expect(decimalSeparatorForLocale('pt_BR'), ',');
    });
    test('dot locales and regional exceptions', () {
      expect(decimalSeparatorForLocale('en_US'), '.');
      expect(decimalSeparatorForLocale('en_GB'), '.');
      expect(decimalSeparatorForLocale('C'), '.');
      expect(decimalSeparatorForLocale(''), '.');
      expect(decimalSeparatorForLocale(null), '.');
      expect(decimalSeparatorForLocale('de_CH'), '.');
      expect(decimalSeparatorForLocale('es_MX'), '.');
    });
  });

  group('formatDecimal', () {
    test('drops trailing .0 and keeps fractions', () {
      expect(formatDecimal(null), '');
      expect(formatDecimal(18.0), '18');
      expect(formatDecimal(18), '18');
      expect(formatDecimal(18.5), '18.5');
      expect(formatDecimal(250.25), '250.25');
    });
    test('uses the requested separator', () {
      expect(formatDecimal(18.5, decimalSeparator: ','), '18,5');
      expect(formatDecimal(18.0, decimalSeparator: ','), '18');
      expect(formatDecimal(9, decimalSeparator: ',', fractionDigits: 1), '9,0');
    });
    test('round-trips with parseDecimal', () {
      for (final v in [0.5, 18.5, 36.25, 250.0, 1000.0]) {
        expect(parseDecimal(formatDecimal(v, decimalSeparator: ',')), v);
        expect(parseDecimal(formatDecimal(v)), v);
      }
    });
  });

  group('formatDecimal precision', () {
    test('no float leftovers', () {
      expect(formatDecimal(0.1 + 0.2), '0.3');
      expect(formatDecimal(0.1 + 0.2, decimalSeparator: ','), '0,3');
      expect(formatDecimal(18.1 + 0.4), '18.5');
    });
    test('no exponent form for tiny values', () {
      expect(formatDecimal(1e-7), '0.0000001');
      expect(formatDecimal(1e-7, decimalSeparator: ','), '0,0000001');
      expect(formatDecimal(1e-12), '0');
      expect(formatDecimal(-1e-12), '0');
    });
    test('no exponent form or int overflow for huge values', () {
      expect(formatDecimal(1e21), '1000000000000000000000');
      expect(formatDecimal(-1e21), '-1000000000000000000000');
      expect(formatDecimal(1e21, fractionDigits: 1),
          '1000000000000000000000.0');
      expect(formatDecimal(1e300).length, 301);
      expect(formatDecimal(1e300), isNot(contains('e')));
    });
    test('fixed precision and negatives', () {
      expect(formatDecimal(9, fractionDigits: 1), '9.0');
      expect(formatDecimal(-0.04, fractionDigits: 1), '0.0');
      expect(formatDecimal(-2.5, decimalSeparator: ','), '-2,5');
      expect(formatDecimal(double.nan), '');
      expect(formatDecimal(double.infinity), '');
    });
  });

  group('parseDecimal thousands grouping', () {
    test('mixed separators: last one is the decimal separator', () {
      expect(parseDecimal('1.234,5'), 1234.5);
      expect(parseDecimal('1,234.5'), 1234.5);
      expect(parseDecimal('12.345.678,25'), 12345678.25);
      expect(parseDecimal('12,345,678.25'), 12345678.25);
      expect(parseDecimal('-1.234,5'), -1234.5);
    });
    test('repeated grouping separator', () {
      expect(parseDecimal('1.234.567'), 1234567);
      expect(parseDecimal('1,234,567'), 1234567);
    });
    test('spaces as grouping', () {
      expect(parseDecimal('1 234,5'), 1234.5);
      expect(parseDecimal('1\u00A0234,5'), 1234.5);
      expect(parseDecimal('1\u202F234.5'), 1234.5);
    });
    test('a single separator is decimal', () {
      expect(parseDecimal('18,5'), 18.5);
      expect(parseDecimal('1,000'), 1.0);
      expect(parseDecimal('1.000'), 1.0);
      expect(parseDecimal('0,25'), 0.25);
    });
    test('rejects malformed grouping', () {
      expect(parseDecimal('1.23,4'), isNull);
      expect(parseDecimal('1,2.3'), isNull);
      expect(parseDecimal('1.234.5'), isNull);
      expect(parseDecimal('1,234,5'), isNull);
      expect(parseDecimal('1.234,5.6'), isNull);
      expect(parseDecimal(',,'), isNull);
    });
    test('still accepts plain and exponent CSV numbers', () {
      expect(parseDecimal('1e-7'), 1e-7);
      expect(parseDecimal('1e+21'), 1e21);
      expect(parseDecimal('-3.75'), -3.75);
    });
  });

  group('round-trip format -> parse', () {
    test('common and edge values in both separators', () {
      for (final v in [
        0.0,
        0.3,
        0.5,
        1e-7,
        9.0,
        18.5,
        36.25,
        250.0,
        1234.5,
        1e21,
        -2.5,
      ]) {
        for (final sep in ['.', ',']) {
          expect(parseDecimal(formatDecimal(v, decimalSeparator: sep)), v,
              reason: 'value $v sep "$sep"');
        }
      }
      expect(parseDecimal(formatDecimal(0.1 + 0.2, decimalSeparator: ',')),
          0.3);
    });
  });
}
