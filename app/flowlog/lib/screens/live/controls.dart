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
    Future<void> Function()? onPhoneBrewStart,
    Future<void> Function()? onPhoneBrewEnd,
    Future<void> Function(double pressureBar)? onForwardPressure,
    Future<void> Function()? onPushScaleConfig,
    ShotSession? session,
  })  : _sampleAdapter = sampleAdapter,
        _onTare = onTare,
        _onPhoneBrewStart = onPhoneBrewStart,
        _onPhoneBrewEnd = onPhoneBrewEnd,
        _onForwardPressure = onForwardPressure,
        _onPushScaleConfig = onPushScaleConfig,
        _session = session ?? ShotSession() {
    _stateSub = _session.stateChanges.listen((_) => _notify());
    _sampleBatchSub = _session.sampleBatches.listen(_onSampleBatch);
  }

  final SensorAdapter _sampleAdapter;
  final Future<void> Function() _onTare;
  final Future<void> Function()? _onPhoneBrewStart;
  final Future<void> Function()? _onPhoneBrewEnd;
  final Future<void> Function(double pressureBar)? _onForwardPressure;
  final Future<void> Function()? _onPushScaleConfig;
  ShotSession _session;
  StreamSubscription<ShotSessionState>? _stateSub;
  StreamSubscription<List<ShotSample>>? _sampleBatchSub;
  DateTime? _sessionStartedAt;
  DateTime? _sessionEndedAt;
  bool _disposed = false;
  bool _startInFlight = false;
  bool _stopInFlight = false;
  String? _lastStartError;
  DateTime? _lastUiNotify;
  Timer? _uiNotifyTimer;

  /// Cleared on successful start; set when connect fails (UI can show snackbar).
  String? get lastStartError => _lastStartError;

  void _onSampleBatch(List<ShotSample> batch) {
    // Full-tree Live rebuilds at 10–20 Hz plus a snackbar overlay is what
    // made the brew UI hitch. Chart already has its own ~30 fps notifier.
    _scheduleUiNotify();
    final forward = _onForwardPressure;
    if (forward == null || batch.isEmpty) {
      return;
    }
    if (sessionState != ShotSessionState.recording &&
        sessionState != ShotSessionState.paused) {
      return;
    }
    // Prefer the newest sample that carries pressure.
    for (var i = batch.length - 1; i >= 0; i--) {
      final p = batch[i].pressureBar;
      if (p != null) {
        unawaited(forward(p));
        break;
      }
    }
  }

  static const _uiNotifyMinInterval = Duration(milliseconds: 50);

  void _scheduleUiNotify() {
    final now = DateTime.now();
    final last = _lastUiNotify;
    if (last == null || now.difference(last) >= _uiNotifyMinInterval) {
      _uiNotifyTimer?.cancel();
      _uiNotifyTimer = null;
      _lastUiNotify = now;
      _notify();
      return;
    }
    _uiNotifyTimer ??= Timer(_uiNotifyMinInterval - now.difference(last), () {
      _uiNotifyTimer = null;
      _lastUiNotify = DateTime.now();
      _notify();
    });
  }

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
  /// Safe to call repeatedly. A stuck prior start (BLE disconnect hang) is
  /// force-cleared so Start never silently no-ops.
  Future<void> start({double? autoStartPressureBar}) async {
    if (_startInFlight) {
      // Previous attempt hung (often BLE disconnect). Force clear and continue.
      _startInFlight = false;
      try {
        await _hardResetToIdle();
      } on Object {
        // continue into a fresh start attempt
      }
    }

    if (!canStart) {
      try {
        await _hardResetToIdle();
      } on Object catch (error) {
        _lastStartError = 'Cannot start brew: $error';
        _notify();
        return;
      }
      if (!canStart) {
        _lastStartError =
            'Cannot start brew (session is ${sessionState.name}). Tap again.';
        _notify();
        return;
      }
    }

    _startInFlight = true;
    _lastStartError = null;
    _notify();
    try {
      if (sessionState == ShotSessionState.stopped) {
        await _replaceSession().timeout(const Duration(seconds: 3));
      }
      if (sessionState != ShotSessionState.idle) {
        await _hardResetToIdle();
      }

      _autoStartPressureBar = autoStartPressureBar;
      _sessionStartedAt = DateTime.now().toUtc();
      _sessionEndedAt = null;

      // Subscribe *before* connect so the first post-connect samples are not
      // dropped (replay adapters and BLE both emit on connect).
      try {
        _session.start(
          _sampleAdapter.samples.map((sample) => sample.toShotSample()),
        );
      } on Object catch (error) {
        _lastStartError = 'Could not start session: $error';
        await _hardResetToIdle();
        return;
      }
      // Focus mode as soon as the session is recording (don't wait on BLE).
      _notify();

      try {
        await _sampleAdapter.connect().timeout(const Duration(seconds: 10));
      } on Object catch (error) {
        // Keep recording if the session already has samples; otherwise roll back.
        if (_session.samples.isEmpty) {
          _lastStartError =
              'Could not start sensors: $error. Check Bluetooth / Sensors tab.';
          try {
            if (_session.state == ShotSessionState.recording ||
                _session.state == ShotSessionState.paused) {
              _session.stop();
            }
          } on Object {
            // ignore
          }
          await _safeDisconnect();
          await _hardResetToIdle();
          return;
        }
      }

      // Best-effort scale prep — never abort an active brew for these.
      var phoneNotified = false;
      try {
        await _onTare().timeout(const Duration(seconds: 4));
      } on Object {
        // Scale tare failed — keep recording pressure.
      }

      final pushCfg = _onPushScaleConfig;
      if (pushCfg != null) {
        try {
          await pushCfg().timeout(const Duration(seconds: 2));
        } on Object {
          // Best-effort.
        }
      }
      final brewStart = _onPhoneBrewStart;
      if (brewStart != null) {
        try {
          await brewStart().timeout(const Duration(seconds: 2));
          phoneNotified = true;
        } on Object {
          // Best-effort.
        }
      }

      // If we somehow rolled back after notifying the scale, clear mirror mode.
      if (phoneNotified && !isBrewing) {
        final brewEnd = _onPhoneBrewEnd;
        if (brewEnd != null) {
          try {
            await brewEnd().timeout(const Duration(seconds: 2));
          } on Object {
            // ignore
          }
        }
      }
    } on Object catch (error) {
      _lastStartError = 'Start brew failed: $error';
      final brewEnd = _onPhoneBrewEnd;
      if (brewEnd != null) {
        try {
          await brewEnd().timeout(const Duration(seconds: 2));
        } on Object {
          // ignore
        }
      }
      await _safeDisconnect();
      try {
        await _hardResetToIdle();
      } on Object {
        // ignore
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
    if (_stopInFlight) {
      return;
    }
    if (!canStop) {
      // Still force teardown if start left things half-open.
      await _hardResetToIdle();
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

      final brewEnd = _onPhoneBrewEnd;
      if (brewEnd != null) {
        try {
          await brewEnd().timeout(const Duration(seconds: 2));
        } on Object {
          // Best-effort.
        }
      }

      await _safeDisconnect();
    } finally {
      _stopInFlight = false;
      _startInFlight = false;
      _notify();
    }
  }

  /// Forces a fresh idle session after a stuck or failed lifecycle.
  Future<void> recoverIfStuck() async {
    _startInFlight = false;
    _stopInFlight = false;
    // Active brew: do not tear down.
    if (canStop) {
      return;
    }
    // Already able to start.
    if (canStart) {
      return;
    }
    await _hardResetToIdle();
  }

  Future<void> _safeDisconnect() async {
    try {
      await _sampleAdapter.disconnect().timeout(const Duration(seconds: 2));
    } on Object {
      // BLE stacks sometimes hang on disconnect — do not block Start forever.
    }
  }

  Future<void> _hardResetToIdle() async {
    await _safeDisconnect();
    try {
      await _replaceSession().timeout(const Duration(seconds: 2));
    } on Object {
      // Last resort: drop listeners and allocate a new session without awaiting
      // a stuck dispose.
      _stateSub?.cancel();
      _sampleBatchSub?.cancel();
      _session = ShotSession();
      _sessionStartedAt = null;
      _sessionEndedAt = null;
      _stateSub = _session.stateChanges.listen((_) => _notify());
      _sampleBatchSub = _session.sampleBatches.listen(_onSampleBatch);
    }
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
    _uiNotifyTimer?.cancel();
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
    _sampleBatchSub = _session.sampleBatches.listen(_onSampleBatch);
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
        final starting = controller.sessionState == ShotSessionState.idle &&
            !brewing; // visual only

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

        Future<void> onBrewPressed() async {
          // Always try recover first so a stuck start never leaves the button dead.
          await controller.recoverIfStuck();
          if (controller.isBrewing) {
            await controller.stop();
            return;
          }
          await controller.start();
          final err = controller.lastStartError;
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }

        final isIdleProminent = !brewing && prominent;

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
              onTap: onBrewPressed,
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
                      starting ? 'Start brew' : 'Start brew',
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
            onPressed: onBrewPressed,
            child: Text(brewing ? 'Stop brew' : 'Start brew'),
          );
        }

        return Semantics(
          button: true,
          enabled: true,
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


