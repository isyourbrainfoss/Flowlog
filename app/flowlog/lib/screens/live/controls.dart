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
          // Custom full-bleed button showing *only* the coffee liquid (no cup rim visible).
          // The entire pill is filled with the animated top-down espresso.
          button = Material(
            color: const Color(0xFF2C211A), // deep coffee liquid color (no separate cup)
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
                    Positioned.fill(
                      child: _AnimatedCoffeeLiquid(),
                    ),
                    // Text centered over the liquid.
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

/// Top-down view into an espresso cup for the prominent Start brew button.
/// Thick dark liquid with a central pour point and gentle expanding ripples
/// (as if espresso is dripping in). Subtle, tasteful animation using low
/// opacity and slow timing. The pill shape approximates the cup top view.
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
    // Rich dark espresso for the thick liquid body.
    // A crema-tinted color used for subtle ripples.
    final liquidColor = const Color(0xFF2C211A); // deep coffee
    final cremaTint = theme.colorScheme.primary.withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _CoffeeLiquidPainter(
            progress: _controller.value,
            liquidColor: liquidColor,
            cremaTint: cremaTint,
          ),
        );
      },
    );
  }
}

/// Custom painter for top-down view of thick coffee filling the *entire* button.
/// No cup/rim visible — just the animated espresso liquid across the full pill.
/// Central drip point + expanding ripples for the "dripping down" effect.
class _CoffeeLiquidPainter extends CustomPainter {
  _CoffeeLiquidPainter({
    required this.progress,
    required this.liquidColor,
    required this.cremaTint,
  });

  final double progress;
  final Color liquidColor;
  final Color cremaTint;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Full coffee — the entire button is thick liquid, no cup/rim.
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fullRRect = RRect.fromRectAndRadius(fullRect, const Radius.circular(32));

    final liquidPaint = Paint()..color = liquidColor;
    canvas.drawRRect(fullRRect, liquidPaint);

    // Depth for thick look.
    final depthPaint = Paint()..color = const Color(0xFF1A120D).withValues(alpha: 0.5);
    canvas.drawRRect(fullRRect.deflate(5), depthPaint);

    // Drips: a few small drips randomly scattered around the center (smooth animated "random").
    final dripPaint = Paint()..color = const Color(0xFF120B08).withValues(alpha: 0.75);
    for (int i = 0; i < 5; i++) {
      final seed = i * 1.618034; // golden ratio for nice distribution
      final phase = progress * 2.3 + seed;
      final ox = math.cos(phase * 1.6 + seed) * 11;   // jitter around center
      final oy = math.sin(phase * 1.3 + seed * 1.7) * 5.5;
      final dripC = center + Offset(ox, oy);
      final dr = 3.2 + math.sin(phase * 4.5 + seed) * 1.3;
      canvas.drawCircle(dripC, dr, dripPaint);
    }

    // Circular ripples (perfect circles, ignore pill shape).
    // Not lines: soft filled disks/bands.
    // Vertical gradient top-to-bottom on the ripples.
    final rippleShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        cremaTint.withValues(alpha: 0.30),
        liquidColor.withValues(alpha: 0.06),
        cremaTint.withValues(alpha: 0.24),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final ripplePaint = Paint()
      ..shader = rippleShader
      ..style = PaintingStyle.fill;

    final maxR = math.min(size.width, size.height) / 2 - 3;
    for (int i = 0; i < 6; i++) {
      final t = ((progress + i * 0.12) % 1.0);
      final r = maxR * t * 0.9;
      canvas.drawCircle(center, r, ripplePaint);
      // Inner to give soft ring/band feel without hard lines.
      final innerA = (0.10 * (1 - t)).clamp(0.0, 0.10);
      final innerP = Paint()..color = liquidColor.withValues(alpha: innerA)..style = PaintingStyle.fill;
      canvas.drawCircle(center, r * 0.78, innerP);
    }

    // Tops and bottoms interact as waves.
    // Subtle horizontal sine waves spanning the view; "top" and "bottom" wave trains
    // have offset phases/freqs so they interfere (add/subtract) like real surface waves.
    final wavePaint = Paint()..color = cremaTint.withValues(alpha: 0.055);
    for (int w = 0; w < 5; w++) {
      final baseY = size.height * (0.15 + w * 0.155);
      final path = Path();
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 3) {
        // Top-originating wave component (stronger influence from upper area)
        final topW = math.sin((x * 0.016) + (progress * 5.2 * math.pi) + w * 0.7) * 2.6 * (1.0 - w * 0.12);
        // Bottom-originating wave component (phase shifted for interaction)
        final botW = math.sin((x * 0.023) + (progress * 3.8 * math.pi) + w + math.pi) * 2.1 * (w * 0.18 + 0.1);
        path.lineTo(x, baseY + topW + botW);
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoffeeLiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.cremaTint != cremaTint;
  }
}


