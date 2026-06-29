import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog/screens/live/metrics_row.dart';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flow stability helpers', () {
    test('isFlowInGoodRange accepts mid-band flow', () {
      expect(isFlowInGoodRange(2.0), isTrue);
      expect(isFlowInGoodRange(kGoodFlowMinGs), isTrue);
      expect(isFlowInGoodRange(kGoodFlowMaxGs), isTrue);
    });

    test('isFlowInGoodRange rejects out-of-band and null flow', () {
      expect(isFlowInGoodRange(null), isFalse);
      expect(isFlowInGoodRange(0.5), isFalse);
      expect(isFlowInGoodRange(3.5), isFalse);
    });

    test('isFlowStable requires neutral trend', () {
      expect(
        isFlowStable(flowGs: 2.0, flowTrendIsNeutral: true),
        isTrue,
      );
      expect(
        isFlowStable(flowGs: 2.0, flowTrendIsNeutral: false),
        isFalse,
      );
      expect(
        isFlowStable(flowGs: 0.5, flowTrendIsNeutral: true),
        isFalse,
      );
    });
  });

  group('ShotEndFeedback', () {
    test('trigger invokes haptic and sound hooks', () async {
      var hapticCount = 0;
      var soundCount = 0;

      final feedback = ShotEndFeedback(
        onHaptic: () => hapticCount++,
        soundPlayer: _CountingSoundPlayer(() => soundCount++),
      );

      await feedback.trigger();

      expect(hapticCount, 1);
      expect(soundCount, 1);
    });

    test('default sound player is a no-op stub', () async {
      await const ShotEndFeedback().trigger();
    });
  });

  group('FlowStabilityPulse', () {
    testWidgets('animates when flow is stable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlowStabilityPulse(
              isStable: true,
              child: Text('flow'),
            ),
          ),
        ),
      );

      final pulse = find.byType(FlowStabilityPulse);
      expect(
        find.descendant(
          of: pulse,
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not animate when flow is unstable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlowStabilityPulse(
              isStable: false,
              child: Text('flow'),
            ),
          ),
        ),
      );

      final pulse = find.byType(FlowStabilityPulse);
      expect(
        find.descendant(
          of: pulse,
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
      expect(find.text('flow'), findsOneWidget);
    });
  });

  group('LiveShotEndListener', () {
    late MockDecentScaleTransport scaleTransport;
    late DecentScaleBleAdapter scaleAdapter;
    late MockReplayAdapter replayAdapter;
    late LiveShotController controller;

    setUp(() {
      scaleTransport = MockDecentScaleTransport();
      scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
      replayAdapter = MockReplayAdapter(
        fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
        speed: 0,
      );
      controller = LiveShotController(
        sampleAdapter: replayAdapter,
        onTare: () => scaleAdapter.tare(),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('fires feedback when recording stops', (tester) async {
      var hapticCount = 0;
      var soundCount = 0;
      final feedback = ShotEndFeedback(
        onHaptic: () => hapticCount++,
        soundPlayer: _CountingSoundPlayer(() => soundCount++),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiveShotEndListener(
            controller: controller,
            shotEndFeedback: feedback,
            child: const SizedBox(),
          ),
        ),
      );

      await tester.runAsync(() async {
        await controller.start();
        await tester.pump();
        await controller.stop();
        await tester.pump();
      });

      expect(hapticCount, 1);
      expect(soundCount, 1);
    });

    testWidgets('does not fire feedback on initial idle state', (tester) async {
      var hapticCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: LiveShotEndListener(
            controller: controller,
            shotEndFeedback: ShotEndFeedback(onHaptic: () => hapticCount++),
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pump();

      expect(hapticCount, 0);
    });
  });

  group('LiveMetricsRow integration', () {
    testWidgets('shows stability pulse for stable in-range flow', (tester) async {
      const previous = ShotSample(
        elapsedMs: 10000,
        pressureBar: 9.0,
        weightG: 20.0,
        flowGs: 2.0,
      );
      const current = ShotSample(
        elapsedMs: 10100,
        pressureBar: 9.0,
        weightG: 20.2,
        flowGs: 2.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMetricsRow(
              sample: current,
              previousSample: previous,
            ),
          ),
        ),
      );

      expect(find.byType(FlowStabilityPulse), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FlowStabilityPulse),
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );
    });
  });

  group('LiveControls integration', () {
    testWidgets('stop button triggers shot-end feedback hook', (tester) async {
      var hapticCount = 0;
      final controller = LiveShotController(
        sampleAdapter: MockReplayAdapter(
          fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
          speed: 0,
        ),
        onTare: () async {},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: LiveShotEndListener(
            controller: controller,
            shotEndFeedback: ShotEndFeedback(onHaptic: () => hapticCount++),
            child: Scaffold(
              body: LiveControls(controller: controller),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_start')));
        await tester.pump();
      });

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_stop')));
        await tester.pump();
      });

      expect(hapticCount, 1);
    });
  });
}

class _CountingSoundPlayer implements ShotEndSoundPlayer {
  _CountingSoundPlayer(this.onPlay);

  final void Function() onPlay;

  @override
  Future<void> play() async {
    onPlay();
  }
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
    '../../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}