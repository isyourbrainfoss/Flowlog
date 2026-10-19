import 'package:flowlog/util/decimal_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDecimalSeparatorOverride = null);

  test('parses dot and comma decimals', () {
    expect(parseDecimal('18.5'), 18.5);
    expect(parseDecimal('18,5'), 18.5);
    expect(parseDecimal(' 9 '), 9);
  });
  test('rejects empty and garbage', () {
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('  '), isNull);
    expect(parseDecimal('abc'), isNull);
    expect(parseDecimal('1,2,3'), isNull);
  });
  test('formatDecimalInput shows numbers back in the device style', () {
    debugDecimalSeparatorOverride = ',';
    expect(formatDecimalInput(18.5), '18,5');
    expect(formatDecimalInput(250.0), '250');
    expect(formatDecimalInput(null), '');
    debugDecimalSeparatorOverride = '.';
    expect(formatDecimalInput(18.5), '18.5');
    expect(formatDecimalInput(9, fractionDigits: 1), '9.0');
  });
}
