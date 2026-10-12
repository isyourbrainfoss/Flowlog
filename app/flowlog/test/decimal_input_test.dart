import 'package:flowlog/util/decimal_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
