import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  test('exports workspace version', () {
    expect(flowlogCoreVersion, '0.0.1');
  });
}