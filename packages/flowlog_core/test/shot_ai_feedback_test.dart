import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}

void main() {
  group('buildShotAiFeedbackPayload', () {
    late Shot shot;

    setUp(() {
      shot = Shot.fromJson(
        jsonDecode(
          File(_fixturePath('shots/minimal_shot.json')).readAsStringSync(),
        ) as Map<String, dynamic>,
      );
    });

    test('includes metadata, summary, and downsampled curve', () {
      final payload = buildShotAiFeedbackPayload(shot: shot);

      expect(payload['format'], 'flowlog-shot-ai-feedback-v1');
      expect(payload['metadata'], isA<Map<String, dynamic>>());
      expect(payload['metadata']['doseG'], 18.0);
      expect(payload['brewSummary'], isA<Map<String, dynamic>>());
      expect(payload['brewSummary']['peakPressureBar'], isNotNull);
      expect(payload['brewSummary']['brewRatio'], closeTo(2.0, 0.01));
      expect(payload['brewSummary']['brewStartTempC'], isNotNull);
      expect(payload['brewSummary']['brewEndTempC'], isNotNull);

      final curve = payload['curve'] as List<dynamic>;
      expect(curve, isNotEmpty);
      expect(curve.length, lessThanOrEqualTo(40));
      expect(curve.first, containsPair('elapsedMs', 0));
    });

    test('includes sensor brew temperatures in brew summary', () {
      final shotWithTemp = shot.copyWith(
        samples: [
          const ShotSample(elapsedMs: 0, pressureBar: 0, tempC: 91.0),
          const ShotSample(elapsedMs: 1000, pressureBar: 9, tempC: 93.0),
          const ShotSample(elapsedMs: 2000, pressureBar: 0, tempC: 40.0),
        ],
      );

      final payload = buildShotAiFeedbackPayload(shot: shotWithTemp);
      final summary = payload['brewSummary'] as Map<String, dynamic>;

      expect(summary['brewStartTempC'], 91.0);
      expect(summary['brewEndTempC'], 93.0);
    });

    test('includes bean context and desired flavor goal', () {
      const bean = Bean(
        id: 'bean-1',
        name: 'Guji',
        origin: 'Ethiopia',
        roastLevel: 'Light',
      );

      final payload = buildShotAiFeedbackPayload(
        shot: shot,
        beanContext: const ShotAiBeanContext(label: 'Guji Natural', bean: bean),
        desiredFlavorGoal: 'brighter acidity',
      );

      expect(payload['desiredFlavorGoal'], 'brighter acidity');
      expect(payload['bean'], isA<Map<String, dynamic>>());
      expect(payload['bean']['displayName'], 'Guji Natural');
      expect(payload['bean']['origin'], 'Ethiopia');
    });
  });

  group('downsampleShotSamples', () {
    test('keeps endpoints and limits point count', () {
      final samples = [
        for (var i = 0; i < 200; i++)
          ShotSample(elapsedMs: i * 100, pressureBar: i * 0.05),
      ];

      final downsampled = downsampleShotSamples(samples, maxPoints: 10);

      expect(downsampled.length, 10);
      expect(downsampled.first['elapsedMs'], 0);
      expect(downsampled.last['elapsedMs'], 19900);
    });
  });

  group('buildShotAiFeedbackClipboardText', () {
    test('embeds prompt, taste goal, and shot JSON block', () {
      final shot = Shot.fromJson(
        jsonDecode(
          File(_fixturePath('shots/minimal_shot.json')).readAsStringSync(),
        ) as Map<String, dynamic>,
      );

      final text = buildShotAiFeedbackClipboardText(
        shot: shot,
        desiredFlavorGoal: 'more sweetness',
      );

      expect(text, contains('My taste goal: more sweetness'));
      expect(text, contains('flowlog-shot-ai-feedback-v1'));
      expect(text, contains('```json'));
      expect(text, contains('plain, readable text'));
      expect(text, contains('Suggested tweaks'));
      expect(text, isNot(contains('suggestedTweaks')));
    });
  });
}