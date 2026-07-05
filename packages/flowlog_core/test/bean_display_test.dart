import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('formatBeanDisplayLabel', () {
    final houseApril = Bean(
      id: 'bean-2',
      name: 'House Blend',
      roastDate: DateTime.utc(2026, 4, 15),
    );
    final houseMarchWithDate = Bean(
      id: 'bean-3',
      name: 'House Blend',
      roastDate: DateTime.utc(2026, 3, 1),
    );

    test('shows plain name when unique', () {
      const solo = Bean(id: 'bean-solo', name: 'Ethiopia');
      expect(formatBeanDisplayLabel(solo), 'Ethiopia');
    });

    test('disambiguates duplicate names with roast dates', () {
      final all = [houseMarchWithDate, houseApril];
      expect(
        formatBeanDisplayLabel(houseMarchWithDate, allBeans: all),
        'House Blend · 2026-03-01',
      );
      expect(
        formatBeanDisplayLabel(houseApril, allBeans: all),
        'House Blend · 2026-04-15',
      );
    });

    test('falls back when duplicates lack roast dates', () {
      const a = Bean(id: 'bean-a', name: 'House Blend', origin: 'Brazil');
      const b = Bean(id: 'bean-b', name: 'House Blend');
      expect(
        formatBeanDisplayLabel(a, allBeans: [a, b]),
        'House Blend · Brazil',
      );
      expect(
        formatBeanDisplayLabel(b, allBeans: [a, b]),
        'House Blend · no roast date',
      );
    });

    test('uses variety to disambiguate duplicate names', () {
      const catuai = Bean(
        id: 'bean-catuai',
        name: 'Rosimeire',
        variety: 'Yellow Catuai',
      );
      const bourbon = Bean(
        id: 'bean-bourbon',
        name: 'Rosimeire',
        variety: 'Red Bourbon',
      );
      expect(
        formatBeanDisplayLabel(catuai, allBeans: [catuai, bourbon]),
        'Rosimeire · Yellow Catuai',
      );
      expect(
        formatBeanDisplayLabel(bourbon, allBeans: [catuai, bourbon]),
        'Rosimeire · Red Bourbon',
      );
    });

    test('uses process to disambiguate duplicate names', () {
      const washed = Bean(
        id: 'bean-washed',
        name: 'Ethiopia',
        process: 'Washed',
      );
      const natural = Bean(
        id: 'bean-natural',
        name: 'Ethiopia',
        process: 'Natural',
      );
      expect(
        formatBeanDisplayLabel(washed, allBeans: [washed, natural]),
        'Ethiopia · Washed',
      );
      expect(
        formatBeanDisplayLabel(natural, allBeans: [washed, natural]),
        'Ethiopia · Natural',
      );
    });
  });
}