// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart';

/// Coordinates [ShotSession] lifecycle with a replay adapter and scale tare.
class LiveShotController extends ChangeNotifier {
  LiveShotController({
    required SensorAdapter sampleAdapter,
    required Future<void> Function() onTare,
    ShotSession? session,
  })  : _sampleAdapter = sampleAdapter,
        _onTare = onTare,
        _session = session ?? ShotSession() {
    _stateSub = _session.stateChanges.listen((_) => _notify());
    _sampleBatchSub = _session.sampleBatches.listen((_) => _notify());
  }

  final SensorAdapter _sampleAdapter;
  final Future<void> Function() _onTare;
  ShotSession _session;
  StreamSubscription<ShotSessionState>? _stateSub;
  StreamSubscription<List<ShotSample>>? _sampleBatchSub;
  DateTime? _sessionStartedAt;
  DateTime? _sessionEndedAt;
  bool _disposed = false;

  ShotSession get session => _session;

  ShotSessionState get sessionState => _session.state;

  int get sampleCount => _session.samples.length;

  List<ShotSample> get samples => _session.samples;

  DateTime? get sessionStartedAt => _sessionStartedAt;

  DateTime? get sessionEndedAt => _sessionEndedAt;

  bool get canSaveShot =>
      sessionState == ShotSessionState.stopped && samples.isNotEmpty;

  bool get canStart =>
      sessionState == ShotSessionState.idle ||
      sessionState == ShotSessionState.stopped;

  bool get canPause => sessionState == ShotSessionState.recording;

  bool get canResume => sessionState == ShotSessionState.paused;

  bool get canStop =>
      sessionState == ShotSessionState.recording ||
      sessionState == ShotSessionState.paused;

  bool get isBrewing => canStop;

  double? _autoStartPressureBar;

  /// The pressure threshold (in bar) that was used to auto-start this brew, if any.
  /// Null if started manually.
  double? get autoStartPressureBar => _autoStartPressureBar;

  /// Tares the scale, connects [sampleAdapter], and begins [ShotSession].
  Future<void> start({double? autoStartPressureBar}) async {
    if (!canStart) {
      return;
    }

    if (sessionState == ShotSessionState.stopped) {
      await _replaceSession();
    }

    _autoStartPressureBar = autoStartPressureBar;

    await _onTare();
    _sessionStartedAt = DateTime.now().toUtc();
    _sessionEndedAt = null;
    // Subscribe before connect so instant replay samples are not missed.
    _session.start(
      _sampleAdapter.samples.map((sample) => sample.toShotSample()),
    );
    await _sampleAdapter.connect();
    _notify();
  }

  void pause() {
    if (!canPause) {
      return;
    }
    _session.pause();
    _notify();
  }

  void resume() {
    if (!canResume) {
      return;
    }
    _session.resume();
    _notify();
  }

  /// Ends recording and disconnects the sample adapter.
  Future<void> stop() async {
    if (!canStop) {
      return;
    }

    _session.stop();
    _sessionEndedAt = DateTime.now().toUtc();
    await _sampleAdapter.disconnect();
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _sampleBatchSub?.cancel();
    unawaited(_session.dispose());
    unawaited(_sampleAdapter.disconnect());
    super.dispose();
  }

  Future<void> _replaceSession() async {
    _stateSub?.cancel();
    _sampleBatchSub?.cancel();
    await _session.dispose();
    _session = ShotSession();
    _sessionStartedAt = null;
    _sessionEndedAt = null;
    _stateSub = _session.stateChanges.listen((_) => _notify());
    _sampleBatchSub = _session.sampleBatches.listen((_) => _notify());
  }
}

/// Single start/stop brew control for a live shot recording.
class LiveControls extends StatelessWidget {
  const LiveControls({
    required this.controller,
    this.prominent = false,
    this.compact = false,
    super.key,
  });

  final LiveShotController controller;

  /// When true, renders a large pill-shaped primary action for phones.
  final bool prominent;

  /// When true, renders a shorter bar suited to landscape fullscreen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final brewing = controller.isBrewing;
        final enabled = brewing ? controller.canStop : controller.canStart;

        final baseStyle = compact
            ? FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              )
            : prominent
                ? FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: const StadiumBorder(),
                    textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  )
                : null;

        final isIdleProminent = !brewing && prominent && enabled;

        Widget buttonChild = Text(brewing ? 'Stop brew' : 'Start brew');

        if (isIdleProminent) {
          buttonChild = Stack(
            alignment: Alignment.center,
            children: [
              // Coffee-like liquid filling lower portion of the button area, with gentle floating wave across full width
              Positioned.fill(
                child: _AnimatedCoffeeLiquid(),
              ),
              // Text on top, with shadow for legibility over the liquid
              Text(
                'Start brew',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 3,
                        ),
                      ],
                    ),
              ),
            ],
          );
        }

        final button = FilledButton(
          key: const Key('live_brew'),
          style: brewing
              ? (baseStyle ?? FilledButton.styleFrom()).merge(
                  FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                )
              : baseStyle,
          onPressed: enabled
              ? () async {
                  if (brewing) {
                    await controller.stop();
                  } else {
                    await controller.start();
                  }
                }
              : null,
          child: buttonChild,
        );

        return Semantics(
          button: true,
          enabled: enabled,
          label: brewing ? 'Stop brew' : 'Start brew',
          child: ExcludeSemantics(child: button),
        );
      },
    );
  }
}

/// Animated coffee-like liquid that gently "floats" with a moving wave surface.
/// Used as a visual affordance inside the prominent idle "Start brew" button.
class _AnimatedCoffeeLiquid extends StatefulWidget {
  const _AnimatedCoffeeLiquid({super.key}); // ignore: unused_element_parameter

  @override
  State<_AnimatedCoffeeLiquid> createState() => _AnimatedCoffeeLiquidState();
}

class _AnimatedCoffeeLiquidState extends State<_AnimatedCoffeeLiquid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Darker coffee liquid, lighter crema foam. Slightly transparent so it blends with button bg.
    final liquidColor = theme.colorScheme.secondaryContainer.withValues(alpha: 0.92);
    final foamColor = theme.colorScheme.primary.withValues(alpha: 0.28);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _CoffeeLiquidPainter(
            progress: _controller.value,
            liquidColor: liquidColor,
            foamColor: foamColor,
          ),
        );
      },
    );
  }
}

class _CoffeeLiquidPainter extends CustomPainter {
  _CoffeeLiquidPainter({
    required this.progress,
    required this.liquidColor,
    required this.foamColor,
  });

  final double progress;
  final Color liquidColor;
  final Color foamColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = liquidColor;

    // Liquid fills the lower ~60% of the button content area for a fuller "in the button" look
    final liquidFillRatio = 0.60;
    final surfaceBase = size.height * (1.0 - liquidFillRatio);

    // Gentle vertical bob for "floating" liquid feel (slow, continuous)
    final bob = math.sin(progress * 2 * math.pi) * 2.5;
    final surfaceY = surfaceBase + bob;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, surfaceY);

    final waveHeight = 7.0;

    // Two overlaid sine waves for natural liquid surface, full width
    for (double x = 0; x <= size.width; x += 1.5) {
      final wave1 = math.sin((x / 32) + (progress * 2 * math.pi)) * waveHeight;
      final wave2 = math.sin((x / 11) + (progress * 3.5 * math.pi)) * (waveHeight * 0.35);
      final y = surfaceY + wave1 + wave2;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Subtle lighter foam band along the surface for coffee crema look
    final foamPaint = Paint()..color = foamColor;
    final foamPath = Path();
    foamPath.moveTo(0, surfaceY - 2);

    for (double x = 0; x <= size.width; x += 1.5) {
      final wave1 = math.sin((x / 32) + (progress * 2 * math.pi)) * waveHeight;
      final wave2 = math.sin((x / 11) + (progress * 3.5 * math.pi)) * (waveHeight * 0.35);
      final y = surfaceY + wave1 + wave2 - 4;
      foamPath.lineTo(x, y);
    }

    foamPath.lineTo(size.width, surfaceY + 6);
    foamPath.lineTo(0, surfaceY + 6);
    foamPath.close();

    canvas.drawPath(foamPath, foamPaint);
  }

  @override
  bool shouldRepaint(covariant _CoffeeLiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.foamColor != foamColor;
  }
}


