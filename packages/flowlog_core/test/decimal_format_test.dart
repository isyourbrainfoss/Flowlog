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
}
