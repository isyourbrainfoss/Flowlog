import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, pressensorLowBatteryWarning;
import 'package:flutter/material.dart' hide ConnectionState;

/// Snackbar shown on Live when the pressensor link comes up while idle.
void showPressensorConnectedSnackBar(
  BuildContext context, {
  required double autoStartThresholdBar,
  required int? batteryPercent,
}) {
  final batteryWarning = pressensorLowBatteryWarning(batteryPercent);
  final message = StringBuffer(
    'Pressensor connected — auto-start at '
    '${autoStartThresholdBar.toStringAsFixed(1)} bar',
  );
  if (batteryWarning != null) {
    message.write('. $batteryWarning');
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: const Key('pressensor_connected_snackbar'),
      content: Text(message.toString()),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Reconnects every paired sensor and reports the outcome in a snackbar.
///
/// [context] must belong to a mounted widget; nothing is shown once it
/// unmounts during the reconnect.
Future<void> reconnectSensorsWithFeedback(
  BuildContext context,
  SensorHub hub,
) async {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reconnecting paired sensors...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  await hub.reconnectPairedDevices();
  if (!context.mounted) {
    return;
  }

  final pairedWithBle = hub.devices
      .where((d) => d.bleRemoteId != null && d.bleRemoteId!.isNotEmpty)
      .toList(growable: false);
  final connected = pairedWithBle
      .where((d) => d.state == ConnectionState.connected)
      .length;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  if (pairedWithBle.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No paired sensors with a BLE id. Pair sensors first.'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } else if (connected == pairedWithBle.length) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          connected == 1
              ? 'Sensor reconnected.'
              : 'All $connected sensors reconnected.',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } else {
    final err = hub.lastError;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          err != null && err.isNotEmpty
              ? 'Reconnect incomplete: $err'
              : 'Reconnect incomplete ($connected/${pairedWithBle.length}).',
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Opens Sensors (under More) so the user can pair hardware from Live.
void openPairSensorsScreen(BuildContext context) {
  FlowlogShellScope.maybeOf(context)?.switchTab(AppTab.more);
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Sensors')),
        body: const SensorsScreen(),
      ),
    ),
  );
}

/// Snackbar confirming a manual weight-stream re-arm.
void showWeightRearmSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      key: Key('weight_stream_rearm_snackbar'),
      content: Text('Refreshing scale weight stream…'),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
