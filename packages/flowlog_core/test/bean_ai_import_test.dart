import 'dart:convert';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('buildBeanAiPrompt', () {
    test('includes field schema, enum values, and missing-info rules', () {
      final prompt = buildBeanAiPrompt();

      expect(prompt, contains('picture of a bag of coffee beans'));
      expect(prompt, contains('Field rules when information is not available'));
      expect(prompt, contains('one markdown code block'));
      expect(prompt, contains('```json'));
      expect(prompt, contains('Never use null'));
      expect(prompt, contains('do not guess'));
      expect(prompt, contains('do not estimate from bean color'));
      expect(prompt, contains('"name"'));
      expect(prompt, contains('"Washed"'));
      expect(prompt, contains('"Medium-Light"'));
    });
  });

  group('parseBeanAiResponse', () {
    test('parses bare JSON object', () {
      final draft = parseBeanAiResponse('''
{
  "name": "Ethiopia Guji",
  "brand": "Onyx",
  "origin": "Ethiopia",
  "variety": "Heirloom",
  "process": "Natural",
  "roastLevel": "Light",
  "roastDate": "2026-03-15",
  "stockG": 250,
  "notes": "Blueberry, jasmine"
}
''');

      expect(draft.name, 'Ethiopia Guji');
      expect(draft.brand, 'Onyx');
      expect(draft.origin, 'Ethiopia');
      expect(draft.variety, 'Heirloom');
      expect(draft.process, 'Natural');
      expect(draft.roastLevel, 'Light');
      expect(draft.roastDate, DateTime.utc(2026, 3, 15));
      expect(draft.stockG, 250);
      expect(draft.notes, 'Blueberry, jasmine');
    });

    test('parses fenced markdown JSON', () {
      final draft = parseBeanAiResponse('''
Here is the bean info:

```json
{
  "name": "House Blend",
  "roastLevel": "medium dark",
  "stockG": "340g"
}
```
''');

      expect(draft.name, 'House Blend');
      expect(draft.roastLevel, 'Medium-Dark');
      expect(draft.stockG, 340);
    });

    test('normalizes process labels', () {
      final draft = parseBeanAiResponse('''
{"name": "Test", "process": "anaerobic natural"}
''');

      expect(draft.process, 'Anaerobic natural');
    });

    test('rejects missing name', () {
      expect(
        () => parseBeanAiResponse('{"brand": "Onyx"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects empty response', () {
      expect(
        () => parseBeanAiResponse('   '),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid roast date', () {
      expect(
        () => parseBeanAiResponse('{"name": "Test", "roastDate": "March 2026"}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('repairMojibake', () {
    test('is idempotent on clean Norwegian text', () {
      const clean = 'Oslo Mørkbrent · kaffebønner · José';
      final fixed = repairMojibake(clean);
      expect(fixed, clean);
    });

    test('undoes multi-layer double-encoding of Mørkbrent (7 rounds)', () {
      // Exactly the corruption found in the Flatpak DB for KAFFA Oslo Mørkbrent.
      var bad = 'Oslo Mørkbrent';
      for (var i = 0; i < 7; i++) {
        bad = latin1.decode(utf8.encode(bad));
      }
      expect(bad.length, 141);
      final fixed = repairMojibake(bad);
      expect(fixed, 'Oslo Mørkbrent');
    });

    test('undoes multi-layer double-encoding of José Espinoza', () {
      var bad = 'José Espinoza, Huila';
      for (var i = 0; i < 11; i++) {
        bad = latin1.decode(utf8.encode(bad));
      }
      expect(bad.length, greaterThan(1000));
      final fixed = repairMojibake(bad);
      expect(fixed, 'José Espinoza, Huila');
    });

    test('fixes single-layer Ã¸ style mojibake', () {
      final fixed = repairMojibake('Oslo MÃ¸rkbrent');
      expect(fixed, 'Oslo Mørkbrent');
    });

    test('repairs notes that had ø stripped to ¸', () {
      final fixed = repairMojibake('M¸rkbrent / Espresso. kaffeb¸nner mix.');
      expect(fixed, contains('Mørkbrent'));
      expect(fixed, contains('kaffebønner'));
    });

    test('returns empty when input is only mojibake garbage', () {
      final bad = '\uFFFD\uFFFD' * 50 + 'ÃÂ' * 30;
      final fixed = repairMojibake(bad);
      expect(fixed?.trim(), isEmpty);
    });
  });
}