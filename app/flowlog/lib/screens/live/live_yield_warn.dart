import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';

/// Fires the early-stop yield warning once per brew when cup weight crosses
/// the warn level.
class LiveYieldWarnTracker {
  bool _fired = false;

  /// Whether the warning already fired for the current brew (drives the
  /// in-HUD warn banner).
  bool get fired => _fired;

  /// Re-arms for a new brew.
  void reset() => _fired = false;

  /// Returns true exactly once per brew, when the warning should fire now.
  ///
  /// [fallbackWeightG] is the freshest live weight; merged samples may end on
  /// a pressure-only tick with null weight if the scale stream is flaky.
  bool check(
    LiveShotController controller, {
    required BrewDefaultsSettings? defaults,
    required double? fallbackWeightG,
  }) {
    if (!controller.isBrewing || _fired) {
      return false;
    }
    if (defaults == null || !defaults.yieldAlertEnabled) {
      return false;
    }
    final samples = controller.samples;
    if (samples.isEmpty) {
      return false;
    }
    double? weight = samples.last.weightG ?? fallbackWeightG;
    if (weight == null) {
      for (
        var i = samples.length - 1;
        i >= 0 && i >= samples.length - 12;
        i--
      ) {
        final w = samples[i].weightG;
        if (w != null) {
          weight = w;
          break;
        }
      }
    }
    if (!shouldFireYieldWarn(
      weightG: weight,
      warnAtG: defaults.effectiveYieldWarnAtG,
      targetYieldG: defaults.targetYieldG,
      alreadyFired: _fired,
    )) {
      return false;
    }

    _fired = true;
    return true;
  }
}
