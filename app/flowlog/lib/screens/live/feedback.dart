import 'dart:async';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lower bound of the target espresso flow band (g/s) for the stability pulse.
const double kGoodFlowMinGs = 1.0;

/// Upper bound of the target espresso flow band (g/s) for the stability pulse.
const double kGoodFlowMaxGs = 3.0;

/// Returns whether [flowGs] sits in the stable/good extraction range.
bool isFlowInGoodRange(double? flowGs) {
  if (flowGs == null) {
    return false;
  }
  return flowGs >= kGoodFlowMinGs && flowGs <= kGoodFlowMaxGs;
}

/// Returns whether flow is in the good range with a neutral trend (stable).
bool isFlowStable({
  required double? flowGs,
  required bool flowTrendIsNeutral,
}) {
  return isFlowInGoodRange(flowGs) && flowTrendIsNeutral;
}

/// Plays a subtle shot-end sound. Default implementation is a no-op stub.
abstract interface class ShotEndSoundPlayer {
  Future<void> play();
}

/// No-op sound player until a real asset is wired in.
class NoOpShotEndSoundPlayer implements ShotEndSoundPlayer {
  const NoOpShotEndSoundPlayer();

  @override
  Future<void> play() async {}
}

/// Shot-end sensory feedback: medium haptic plus optional sound.
class ShotEndFeedback {
  const ShotEndFeedback({
    this.onHaptic,
    ShotEndSoundPlayer? soundPlayer,
  }) : soundPlayer = soundPlayer ?? const NoOpShotEndSoundPlayer();

  final VoidCallback? onHaptic;
  final ShotEndSoundPlayer soundPlayer;

  Future<void> trigger() async {
    final haptic = onHaptic ?? HapticFeedback.mediumImpact;
    haptic();
    await soundPlayer.play();
  }
}

/// Subtle glow pulse around a widget when flow is in a stable/good range.
class FlowStabilityPulse extends StatefulWidget {
  const FlowStabilityPulse({
    required this.isStable,
    required this.child,
    super.key,
  });

  final bool isStable;
  final Widget child;

  @override
  State<FlowStabilityPulse> createState() => _FlowStabilityPulseState();
}

class _FlowStabilityPulseState extends State<FlowStabilityPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(FlowStabilityPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStable != widget.isStable) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isStable) {
      if (!_controller.isAnimating) {
        unawaited(_controller.repeat(reverse: true));
      }
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isStable) {
      return widget.child;
    }

    final glowColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: 'Flow stable',
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.15 + (0.35 * t)),
                  blurRadius: 6 + (8 * t),
                  spreadRadius: t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Fires [ShotEndFeedback] when a live recording transitions to stopped.
class LiveShotEndListener extends StatefulWidget {
  const LiveShotEndListener({
    required this.controller,
    required this.child,
    this.shotEndFeedback = const ShotEndFeedback(),
    super.key,
  });

  final LiveShotController controller;
  final Widget child;
  final ShotEndFeedback shotEndFeedback;

  @override
  State<LiveShotEndListener> createState() => _LiveShotEndListenerState();
}

class _LiveShotEndListenerState extends State<LiveShotEndListener> {
  late bool _wasActive;

  @override
  void initState() {
    super.initState();
    _wasActive = _isActive(widget.controller.sessionState);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(LiveShotEndListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _wasActive = _isActive(widget.controller.sessionState);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  bool _isActive(ShotSessionState state) {
    return state == ShotSessionState.recording ||
        state == ShotSessionState.paused;
  }

  void _onControllerChanged() {
    final state = widget.controller.sessionState;
    if (_wasActive && state == ShotSessionState.stopped) {
      unawaited(widget.shotEndFeedback.trigger());
    }
    _wasActive = _isActive(state);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}