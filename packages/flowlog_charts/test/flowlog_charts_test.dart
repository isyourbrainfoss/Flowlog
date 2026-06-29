import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports workspace version', () {
    expect(flowlogChartsVersion, '0.0.1');
  });
}