import 'dart:async';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, DecentScaleBleAdapter;
import 'package:flutter/foundation.dart';

/// Tracks the live cup weight shown on Live and whether the scale's weight
/// stream is healthy, re-arming a silent stream once per brew.
class LiveWeightTracker {
  LiveWeightTracker({
    required this.resolveHub,
    required this.resolveSource,
    required this.resolveController,
  });

  /// Current [SensorHub] (may be null in tests without a hub scope).
  final SensorHub? Function() resolveHub;

  /// Current live sensor source, when bound.
  final LiveSensorSource? Function() resolveSource;

  /// Current Live controller, when bound.
  final LiveShotController? Function() resolveController;

  /// Latest known cup weight (g).
  final ValueNotifier<double?> weight = ValueNotifier<double?>(null);

  /// When [weight] was last confirmed by a real scale packet.
  final ValueNotifier<DateTime?> lastUpdate = ValueNotifier<DateTime?>(null);

  /// One automatic weight-stream re-arm per brew when the scale is silent.
  bool _rearmAttempted = false;

  /// Clears readings (reconnect, new brew).
  void clear() {
    weight.value = null;
    lastUpdate.value = null;
  }

  /// Re-arms tracking for a new brew.
  void resetForNewBrew() {
    _rearmAttempted = false;
    clear();
  }

  /// Updates [weight]/[lastUpdate] from [controller]'s latest samples.
  void track(LiveShotController controller) {
    final samples = controller.samples;
    if (samples.isEmpty) {
      _maybeRearmSilentScale(controller);
      return;
    }
    // Prefer the true BLE receive time from the hub scale adapter. Merged
    // samples carry the last weight on every pressure tick, so sample.weightG
    // alone cannot prove the scale is still streaming.
    final hub = resolveHub();
    final adapter = hub?.activeAdapterFor(SensorKind.scale);
    if (adapter is DecentScaleBleAdapter) {
      final rxMs = adapter.lastWeightReceiveMs;
      if (rxMs != null) {
        final age = DateTime.now().millisecondsSinceEpoch - rxMs;
        if (age <= kWeightStreamFreshWindow.inMilliseconds) {
          // Latest carry-forward weight for display.
          for (var i = samples.length - 1; i >= 0; i--) {
            final w = samples[i].weightG;
            if (w != null) {
              weight.value = w;
              break;
            }
          }
          lastUpdate.value = DateTime.fromMillisecondsSinceEpoch(rxMs);
          _rearmAttempted = false;
          return;
        }
      }
    } else {
      // No hub adapter (tests / factory path): fall back to sample presence.
      for (var i = samples.length - 1; i >= 0 && i >= samples.length - 3; i--) {
        final w = samples[i].weightG;
        if (w != null) {
          weight.value = w;
          lastUpdate.value = DateTime.now();
          _rearmAttempted = false;
          _maybeRearmSilentScale(controller);
          return;
        }
      }
    }
    _maybeRearmSilentScale(controller);
  }

  /// Weight-stream health for the yield bar.
  WeightStreamHealth health({required bool isBrewing}) {
    final hub = resolveHub();
    final source = resolveSource();
    final controller = resolveController();
    final scalePaired =
        source?.scalePaired ?? hub?.hasKind(SensorKind.scale) ?? false;
    final linked =
        source?.scaleLinkConnected ??
        (hub?.scaleState == ConnectionState.connected);
    final adapter = hub?.activeAdapterFor(SensorKind.scale);
    int? rxMs;
    if (adapter is DecentScaleBleAdapter) {
      rxMs = adapter.lastWeightReceiveMs;
    } else {
      final last = lastUpdate.value;
      rxMs = last?.millisecondsSinceEpoch;
    }
    final started = controller?.sessionStartedAt;
    return resolveWeightStreamHealth(
      scalePaired: scalePaired,
      scaleLinked: linked,
      isBrewing: isBrewing,
      shotHasWeight: (controller?.samples ?? const <ShotSample>[]).any(
        (s) => s.weightG != null,
      ),
      lastWeightReceiveMs: rxMs,
      brewElapsed: started == null ? null : DateTime.now().difference(started),
    );
  }

  void _maybeRearmSilentScale(LiveShotController controller) {
    if (!controller.isBrewing || _rearmAttempted) {
      return;
    }
    if (health(isBrewing: true) != WeightStreamHealth.linkedNoWeight) {
      return;
    }
    // Give the stream a moment after start before treating silence as a fault.
    final started = controller.sessionStartedAt;
    if (started != null &&
        DateTime.now().difference(started) < const Duration(seconds: 8)) {
      return;
    }
    _rearmAttempted = true;
    unawaited(resolveSource()?.rearmWeightStream());
  }

  void dispose() {
    weight.dispose();
    lastUpdate.dispose();
  }
}
