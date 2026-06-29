import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';

/// Live shot tab: recording controls wired to [ShotSession] and mock sensors.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    this.controller,
  });

  /// Optional override for tests or dependency injection.
  final LiveShotController? controller;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final LiveShotController _controller;
  late final bool _ownsController;
  MockReplayAdapter? _replayAdapter;
  DecentScaleBleAdapter? _scaleAdapter;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final scaleTransport = MockDecentScaleTransport();
      _scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
      _replayAdapter = MockReplayAdapter(
        fixturePath: _defaultFixturePath(),
        speed: 0,
      );
      _controller = LiveShotController(
        sampleAdapter: _replayAdapter!,
        onTare: () => _scaleAdapter!.tare(),
      );
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.sessionState;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Session: ${state.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${_controller.sampleCount} samples',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              LiveControls(controller: _controller),
            ],
          ),
        );
      },
    );
  }
}

String _defaultFixturePath() {
  const candidates = [
    '../../fixtures/sensor_streams/demo_shot.jsonl',
    '../../../fixtures/sensor_streams/demo_shot.jsonl',
    'fixtures/sensor_streams/demo_shot.jsonl',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) {
      return file.path;
    }
  }

  throw StateError(
    'demo_shot.jsonl fixture not found; run from the Flowlog workspace root.',
  );
}