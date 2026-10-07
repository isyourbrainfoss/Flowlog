import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/scale_settings_store.dart';

/// Pushes target yield / warn / pressure range to the scale's own display.
///
/// Prefers the dedicated scale settings; falls back to [brewDefaults] (then
/// app defaults) for the yield warn level when the scale setting is unset.
Future<void> pushLiveScaleDisplayConfig(
  LiveSensorSource source, {
  required BrewDefaultsSettings? brewDefaults,
  ScaleSettingsStore? scaleSettingsStore,
}) async {
  final scaleSettings = await (scaleSettingsStore ?? ScaleSettingsStore())
      .load();
  final target = scaleSettings.targetYieldG;
  final warn = scaleSettings.warnAtG > 0
      ? scaleSettings.warnAtG
      : (brewDefaults?.effectiveYieldWarnAtG ?? kDefaultYieldWarnAtG);
  await source.pushScaleDisplayConfig(
    targetYieldG: target.round(),
    warnAtG: warn.round(),
    pressureMinBar: scaleSettings.pressureMinBar.round(),
    pressureMaxBar: scaleSettings.pressureMaxBar.round(),
  );
}
