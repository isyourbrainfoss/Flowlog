import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/fullscreen_chart.dart';
import 'package:flowlog/screens/live/idle_sensor_status.dart';
import 'package:flowlog/screens/live/live_pressure_bar.dart';
import 'package:flowlog/screens/live/live_target_gamification.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;

/// Idle/stopped Live layout: pins the chart above controls when there is
/// room, otherwise scrolls both as one column.
class LiveIdleLayout extends StatelessWidget {
  const LiveIdleLayout({
    super.key,
    required this.pinChart,
    required this.useCompactLayout,
    required this.chartSection,
    required this.controlsSection,
  });

  final bool pinChart;
  final bool useCompactLayout;
  final Widget chartSection;
  final Widget controlsSection;

  @override
  Widget build(BuildContext context) {
    return pinChart
        ? Column(
            key: const ValueKey('live-pinned-layout'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(child: chartSection),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: useCompactLayout ? 0 : 8),
                  child: controlsSection,
                ),
              ),
            ],
          )
        : SingleChildScrollView(
            key: const ValueKey('live-scroll-layout'),
            padding: EdgeInsets.symmetric(vertical: useCompactLayout ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [chartSection, controlsSection],
            ),
          );
  }
}

/// Banners, sensor status, and the chart shown above idle controls.
class LiveIdleChartSection extends StatelessWidget {
  const LiveIdleChartSection({
    super.key,
    required this.horizontalPadding,
    required this.demoModeActive,
    required this.onDismissDemoMode,
    required this.repeatController,
    required this.sensorStatus,
    required this.chartHeight,
    required this.samplesNotifier,
    required this.annotationsNotifier,
    required this.interactionController,
    required this.targetPressureSamples,
    required this.onOpenFullscreenChart,
  });

  final double horizontalPadding;
  final bool demoModeActive;
  final VoidCallback onDismissDemoMode;

  /// Active repeat-shot prefill source; shows the repeat banner when set.
  final RepeatShotController? repeatController;

  /// Sensor status card (idle/stopped only); null hides it.
  final Widget? sensorStatus;
  final double chartHeight;
  final ValueNotifier<List<ShotSample>> samplesNotifier;
  final ValueNotifier<List<ShotAnnotation>> annotationsNotifier;
  final ChartInteractionController interactionController;
  final List<ShotSample> targetPressureSamples;
  final VoidCallback onOpenFullscreenChart;

  @override
  Widget build(BuildContext context) {
    final repeat = repeatController;
    final prefill = repeat?.prefill;
    final status = sensorStatus;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (demoModeActive) DemoModeBanner(onDismiss: onDismissDemoMode),
          if (demoModeActive) const SizedBox(height: 8),
          if (prefill != null)
            RepeatShotBanner(
              profileName: prefill.profile.name,
              onDismiss: repeat!.clear,
            ),
          if (prefill != null) const SizedBox(height: 8),
          ?status,
          if (status != null) const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DualCurveChart(
                height: chartHeight,
                samplesNotifier: samplesNotifier,
                annotationsNotifier: annotationsNotifier,
                interactionController: interactionController,
                denseTimeAxis: true,
                targetPressureSamples: targetPressureSamples,
              ),
              Positioned(
                right: 4,
                bottom: 28,
                child: LiveFullscreenChartButton(
                  onPressed: onOpenFullscreenChart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Idle pressensor status card, rebuilt on [hub] changes only.
///
/// Live's main tree deliberately does not listen to the hub (BLE notifies
/// several times a second); this card does so locally.
class LiveIdleSensorStatus extends StatelessWidget {
  const LiveIdleSensorStatus({
    super.key,
    required this.hub,
    required this.autoStartController,
    required this.pressureBarNotifier,
    required this.lastUpdateNotifier,
    required this.onReconnect,
    required this.onPair,
  });

  final SensorHub? hub;
  final AutoStartSettingsController autoStartController;
  final ValueNotifier<double?> pressureBarNotifier;
  final ValueNotifier<DateTime?> lastUpdateNotifier;
  final Future<void> Function() onReconnect;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final hub = this.hub;
    if (hub == null) {
      return IdleSensorStatus(
        pressureBarNotifier: pressureBarNotifier,
        lastUpdateNotifier: lastUpdateNotifier,
        pressensorPaired: false,
        pressensorLinkState: ConnectionState.disconnected,
        onReconnect: onReconnect,
        onPair: onPair,
        autoStartEnabled: autoStartController.settings.enabled,
        autoStartThreshold: autoStartController.settings.startThresholdBar,
      );
    }
    return ListenableBuilder(
      listenable: hub,
      builder: (context, _) {
        return IdleSensorStatus(
          pressureBarNotifier: pressureBarNotifier,
          lastUpdateNotifier: lastUpdateNotifier,
          pressensorPaired: hub.hasKind(SensorKind.pressensor),
          pressensorLinkState: hub.pressensorState,
          onReconnect: onReconnect,
          onPair: onPair,
          autoStartEnabled: autoStartController.settings.enabled,
          autoStartThreshold: autoStartController.settings.startThresholdBar,
        );
      },
    );
  }
}

/// Post-brew metrics, yield/pressure bars, gamification, and save/repeat
/// actions below the idle chart.
class LiveIdleControlsSection extends StatelessWidget {
  const LiveIdleControlsSection({
    super.key,
    required this.controller,
    required this.horizontalPadding,
    required this.useCompactLayout,
    required this.latestSample,
    required this.liveWeightG,
    required this.targetYieldG,
    required this.warnAtG,
    required this.weightHealth,
    required this.onRearmWeight,
    required this.targetPressure,
    required this.hasTargetCurve,
    required this.gamification,
    required this.showSaveButton,
    required this.onRepeatShot,
    required this.onSaveShot,
  });

  final LiveShotController controller;
  final double horizontalPadding;
  final bool useCompactLayout;
  final ShotSample? latestSample;
  final double? liveWeightG;
  final double targetYieldG;
  final double warnAtG;

  /// Weight-stream health; only needed for the stopped-session bars.
  final WeightStreamHealth? weightHealth;
  final VoidCallback onRearmWeight;
  final double? targetPressure;
  final bool hasTargetCurve;
  final LiveTargetGamificationStats gamification;

  /// False once the session was (auto-)saved.
  final bool showSaveButton;
  final VoidCallback onRepeatShot;
  final VoidCallback onSaveShot;

  @override
  Widget build(BuildContext context) {
    final state = controller.sessionState;
    final latest = latestSample;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        8,
        horizontalPadding,
        useCompactLayout ? 12 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((state == ShotSessionState.stopped) && latest != null) ...[
            LiveMetricsRow(
              metrics: LiveMetrics.fromStoppedSession(controller.samples),
            ),
            const SizedBox(height: 8),
            LiveYieldProgress(
              weightG: latest.weightG ?? liveWeightG,
              targetYieldG: targetYieldG,
              warnAtG: warnAtG,
              showWarnBanner: false,
              weightHealth: weightHealth ?? WeightStreamHealth.notExpected,
              onRearmWeight: onRearmWeight,
            ),
            const SizedBox(height: 6),
            LivePressureDeviationBar(
              currentPressure: latest.pressureBar,
              targetPressure: targetPressure,
            ),
            if (hasTargetCurve) ...[
              const SizedBox(height: 4),
              LiveTargetGamification(stats: gamification),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            '${controller.sampleCount} samples',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Session: ${state.name}',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (controller.canSaveShot) ...[
            Align(
              alignment: Alignment.center,
              child: RepeatShotButton(onPressed: onRepeatShot),
            ),
            if (showSaveButton) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('save_current_shot_button'),
                onPressed: onSaveShot,
                icon: const Icon(Icons.save),
                label: const Text('Save shot'),
              ),
            ],
          ],
          if (controller.canSaveShot) const SizedBox(height: 16),
        ],
      ),
    );
  }
}
