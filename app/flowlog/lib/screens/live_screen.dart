import 'dart:async';
import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';

/// Live shot tab: recording controls, live chart, metrics, and god-shot save.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    this.controller,
    this.shotRepository,
    this.onShotSaved,
    this.shotIdGenerator = generateShotId,
  });

  /// Optional override for tests or dependency injection.
  final LiveShotController? controller;

  /// Optional repository override; defaults to a temp-file database.
  final ShotRepository? shotRepository;

  /// Called after a shot is persisted (useful in tests).
  final void Function(Shot shot)? onShotSaved;

  /// Generates ids for newly saved shots.
  final ShotIdGenerator shotIdGenerator;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final LiveShotController _controller;
  late final bool _ownsController;
  late final ValueNotifier<List<ShotSample>> _samplesNotifier;
  MockReplayAdapter? _replayAdapter;
  DecentScaleBleAdapter? _scaleAdapter;
  ShotRepository? _shotRepository;
  FlowlogDatabase? _database;
  bool _ownsRepository = false;
  bool _savingShot = false;

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

    _samplesNotifier = ValueNotifier<List<ShotSample>>(
      List<ShotSample>.from(_controller.samples),
    );
    _controller.addListener(_syncSamples);
  }

  @override
  void dispose() {
    _controller.removeListener(_syncSamples);
    _samplesNotifier.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsRepository) {
      unawaited(_database?.close());
    }
    super.dispose();
  }

  void _syncSamples() {
    _samplesNotifier.value = List<ShotSample>.from(_controller.samples);
  }

  Future<ShotRepository> _ensureRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _shotRepository = ShotRepository(_database!);
    _ownsRepository = true;
    return _shotRepository!;
  }

  Future<void> _onStarShotPressed() async {
    if (!_controller.canSaveShot || _savingShot) {
      return;
    }

    final startedAt = _controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    setState(() => _savingShot = true);
    try {
      final repository = await _ensureRepository();
      if (!mounted) {
        return;
      }

      await runStarShotSaveFlow(
        context: context,
        repository: repository,
        samples: _controller.samples,
        startedAt: startedAt,
        endedAt: _controller.sessionEndedAt,
        idGenerator: widget.shotIdGenerator,
        onSaved: widget.onShotSaved,
      );
    } finally {
      if (mounted) {
        setState(() => _savingShot = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.sessionState;
        final samples = _controller.samples;
        final latestSample = samples.isEmpty ? null : samples.last;
        final previousSample =
            samples.length < 2 ? null : samples[samples.length - 2];

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DualCurveChart(samplesNotifier: _samplesNotifier),
                const SizedBox(height: 8),
                if (latestSample != null)
                  LiveMetricsRow(
                    sample: latestSample,
                    previousSample: previousSample,
                  )
                else
                  const LiveMetricsRow(
                    metrics: LiveMetrics(elapsedMs: 0),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Session: ${state.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_controller.sampleCount} samples',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                LiveControls(controller: _controller),
              ],
            ),
          ),
          floatingActionButton: StarShotFab(
            enabled: _controller.canSaveShot && !_savingShot,
            onPressed: _onStarShotPressed,
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