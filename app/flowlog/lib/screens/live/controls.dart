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

        late final Widget button;

        if (isIdleProminent) {
          // Custom full-bleed button. The liquid painter now animates across
          // the full height of the pill with subtle ripples (not just the top).
          button = Material(
            color: const Color(0xFF3D2E24), // dark coffee cup color
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                await controller.start();
              },
              customBorder: const StadiumBorder(),
              child: SizedBox(
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Liquid now paints the full 64px height of the button.
                    Positioned.fill(
                      child: _AnimatedCoffeeLiquid(),
                    ),
                    // Text centered over the liquid/foam.
                    Text(
                      'Start brew',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF5F0E8), // light crema for contrast
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 3,
                              ),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          Widget buttonChild = Text(brewing ? 'Stop brew' : 'Start brew');

          button = FilledButton(
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
        }

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

/// Animated coffee-like liquid filling the entire prominent Start button.
/// Uses a subtle surface wave + low-opacity internal ripples at multiple
/// depths so the gentle floating motion is visible across the *whole* height.
/// Animation is intentionally slow and low-contrast for subtlety.
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
      duration: const Duration(milliseconds: 4800),
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
    // Liquid is a rich dark coffee color filling most of the pill.
    // Foam is a lighter crema sitting on the animated surface.
    // These sit on top of the button's cup background color.
    final liquidColor = const Color(0xFF2C211A); // deep coffee
    final foamColor = theme.colorScheme.primary.withValues(alpha: 0.45);

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

    // Liquid fills nearly the entire button height. Surface sits near the
    // very top so the liquid body occupies (almost) the whole visual pill.
    final surfaceBase = size.height * 0.10;

    // Gentle vertical bob for "floating" liquid feel (slow, continuous)
    final bob = math.sin(progress * 2 * math.pi) * 1.8;
    final surfaceY = surfaceBase + bob;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, surfaceY);

    final waveHeight = 5.5;

    // Subtle surface waves
    for (double x = 0; x <= size.width; x += 1.5) {
      final wave1 = math.sin((x / 32) + (progress * 2 * math.pi)) * waveHeight;
      final wave2 = math.sin((x / 13) + (progress * 3.9 * math.pi)) * (waveHeight * 0.35);
      final y = surfaceY + wave1 + wave2;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Lighter foam "crema" band sitting on the surface (subtle)
    final foamPaint = Paint()..color = foamColor;
    final foamPath = Path();
    foamPath.moveTo(0, surfaceY - 2);

    for (double x = 0; x <= size.width; x += 1.5) {
      final wave1 = math.sin((x / 32) + (progress * 2 * math.pi)) * waveHeight;
      final wave2 = math.sin((x / 13) + (progress * 3.9 * math.pi)) * (waveHeight * 0.35);
      final y = surfaceY + wave1 + wave2 - 3;
      foamPath.lineTo(x, y);
    }

    foamPath.lineTo(size.width, surfaceY + 5);
    foamPath.lineTo(0, surfaceY + 5);
    foamPath.close();

    canvas.drawPath(foamPath, foamPaint);

    // Subtle internal ripples throughout the *entire* liquid body so the
    // animation is visible across the whole button height (not just near the top).
    final ripplePaint = Paint()
      ..color = foamColor.withValues(alpha: 0.13)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final liquidHeight = size.height - surfaceY;
    for (int i = 0; i < 5; i++) {
      final depth = 0.15 + (i * 0.17); // spread ripples from near surface down toward bottom
      final yBase = surfaceY + liquidHeight * depth +
          math.sin((progress + i * 0.17) * 2 * math.pi) * 0.8; // tiny vertical drift

      final rPath = Path();
      rPath.moveTo(0, yBase);

      final rAmp = 2.2;
      final rFreq = 26 + (i % 2) * 5;

      for (double x = 0; x <= size.width; x += 2.0) {
        final wy = math.sin((x / rFreq) + (progress * (1.7 + i * 0.35) * 2 * math.pi)) * rAmp;
        rPath.lineTo(x, yBase + wy);
      }
      canvas.drawPath(rPath, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoffeeLiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.foamColor != foamColor;
  }
}


