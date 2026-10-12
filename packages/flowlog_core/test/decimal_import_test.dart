import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  test('parseDecimal accepts dot and comma', () {
    expect(parseDecimal('18,5'), 18.5);
    expect(parseDecimal('18.5'), 18.5);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('1,2,3'), isNull);
  });

  test('CSV import accepts quoted comma decimals', () {
    const csv = 'key,value\n'
        'export_version,1\n'
        'id,a\n'
        'started_at,2026-01-01T00:00:00.000Z\n'
        'dose_g,"18,5"\n'
        '\n'
        'elapsed_ms,pressure_bar,weight_g,flow_gs,temp_c\n'
        '0,"8,25",,,\n';
    final shot = importShotFromCsv(csv);
    expect(shot.doseG, 18.5);
    expect(shot.samples.single.pressureBar, 8.25);
  });

  test('bean AI import accepts comma decimals and thousands', () {
    expect(parseBeanAiResponse('{"name":"A","stockG":"250,5 g"}').stockG,
        250.5);
    expect(parseBeanAiResponse('{"name":"A","stockG":"1,000g"}').stockG, 1000);
    expect(parseBeanAiResponse('{"name":"A","stockG":"1.000 g"}').stockG, 1000);
    expect(parseBeanAiResponse('{"name":"A","stockG":"340g"}').stockG, 340);
  });
}
