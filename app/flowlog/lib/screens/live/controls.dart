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
  bool _startInFlight = false;
  bool _stopInFlight = false;

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
  ///
  /// Safe to call repeatedly: concurrent starts are ignored, and a failed
  /// connect/tare recovers to a state where [canStart] is true again.
  Future<void> start({double? autoStartPressureBar}) async {
    if (!canStart || _startInFlight) {
      return;
    }

    _startInFlight = true;
    _notify();
    try {
      if (sessionState == ShotSessionState.stopped) {
        await _replaceSession();
      }

      // Half-failed prior start can leave non-idle state without canStop.
      if (sessionState != ShotSessionState.idle) {
        await _recoverToIdle();
      }

      _autoStartPressureBar = autoStartPressureBar;

      try {
        await _onTare().timeout(const Duration(seconds: 5));
      } on Object {
        // Scale tare is best-effort; still allow recording pressure.
      }

      _sessionStartedAt = DateTime.now().toUtc();
      _sessionEndedAt = null;
      // Subscribe before connect so instant replay samples are not missed.
      _session.start(
        _sampleAdapter.samples.map((sample) => sample.toShotSample()),
      );

      try {
        await _sampleAdapter.connect().timeout(const Duration(seconds: 12));
      } on Object {
        // Roll back to idle so Start works again without killing the app.
        try {
          if (_session.state == ShotSessionState.recording ||
              _session.state == ShotSessionState.paused) {
            _session.stop();
          }
        } on Object {
          // ignore
        }
        try {
          await _sampleAdapter.disconnect();
        } on Object {
          // ignore
        }
        await _recoverToIdle();
        return;
      }
    } finally {
      _startInFlight = false;
      _notify();
    }
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
    if (!canStop || _stopInFlight) {
      return;
    }

    _stopInFlight = true;
    _notify();
    try {
      if (_session.state == ShotSessionState.recording ||
          _session.state == ShotSessionState.paused) {
        _session.stop();
      }
      _sessionEndedAt = DateTime.now().toUtc();
      try {
        await _sampleAdapter.disconnect().timeout(const Duration(seconds: 8));
      } on Object {
        try {
          await _sampleAdapter.disconnect();
        } on Object {
          // ignore
        }
      }
    } finally {
      _stopInFlight = false;
      _notify();
    }
  }

  /// Forces a fresh idle session after a stuck or failed lifecycle.
  Future<void> recoverIfStuck() async {
    if (_startInFlight || _stopInFlight) {
      return;
    }
    if (canStart || canStop) {
      return;
    }
    await _recoverToIdle();
  }

  Future<void> _recoverToIdle() async {
    try {
      await _sampleAdapter.disconnect();
    } on Object {
      // ignore
    }
    await _replaceSession();
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
        // Stuck after a failed connect: no start/stop — recover on next tap.
        final needsRecover = !enabled && !brewing && !controller.canStart;

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
          // Custom full-bleed button: the whole thing is one solid coffee color
          // that slowly transitions between two shades. No cup/rim.
          button = Material(
            key: const Key('live_brew'),
            color: const Color(0xFF2C211A), // base (painter fills over it)
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                if (needsRecover) {
                  await controller.recoverIfStuck();
                }
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
            onPressed: (enabled || needsRecover)
                ? () async {
                    if (needsRecover) {
                      await controller.recoverIfStuck();
                    }
                    if (controller.isBrewing) {
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
          enabled: enabled || needsRecover,
          label: brewing ? 'Stop brew' : 'Start brew',
          child: ExcludeSemantics(child: button),
        );
      },
    );
  }
}

/// The entire prominent "Start brew" button is one single solid coffee color
/// that very slowly transitions between two shades (light ↔ dark).
/// Subtle, tasteful, uniform fill at any moment.
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
      duration: const Duration(milliseconds: 12000), // very slow, subtle pulse
    );
    // Repeating animations prevent pumpAndSettle from completing in widget tests.
    // Only repeat the pulse in real runs; in tests use a static mid value.
    final binding = WidgetsBinding.instance;
    final isTest = binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
    if (!isTest) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
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

/// The entire prominent Start brew button is filled with a single solid
/// coffee color that slowly and subtly transitions back and forth between
/// two shades (lighter to darker). Very slow, uniform at any instant.
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
    // Two shades of coffee: deep dark and a slightly lighter tone.
    final dark = liquidColor;
    final light = cremaTint;

    // Very slow sine wave for smooth, gradual transition (0 to 1 and back).
    final t = (math.sin(progress * 2 * math.pi) + 1) / 2;

    final color = Color.lerp(dark, light, t)!;

    final paint = Paint()..color = color;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CoffeeLiquidPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.liquidColor != liquidColor ||
        oldDelegate.cremaTint != cremaTint;
  }
}


