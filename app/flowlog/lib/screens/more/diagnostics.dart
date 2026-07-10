import 'dart:async';

import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, isPressensorLowBattery;
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart' hide ConnectionState;

/// Sensor diagnostics: RSSI placeholder, reconnect log, and last error.
class SensorDiagnosticsScreen extends StatelessWidget {
  const SensorDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = SensorHubScope.of(context);
    final devices = hub.devices;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Diagnostics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Connection troubleshooting for paired sensors. Live BLE metrics '
          'will populate here once hardware pairing lands.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        _LastErrorCard(errorMessage: hub.lastError),
        const SizedBox(height: 16),
        Text(
          'Signal strength',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          const _EmptyDiagnosticsHint(
            message: 'Pair a sensor to see RSSI placeholders.',
          )
        else
          for (final device in devices) ...[
            _RssiCard(
              deviceName: device.name,
              rssi: hub.rssiFor(device.id),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        Text(
          'Battery',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (devices.where((device) => device.kind == SensorKind.pressensor).isEmpty)
          const _EmptyDiagnosticsHint(
            message: 'Pair a Pressensor to see battery level.',
          )
        else
          for (final device in devices.where(
            (entry) => entry.kind == SensorKind.pressensor,
          )) ...[
            _BatteryCard(
              deviceName: device.name,
              percent: hub.batteryPercentFor(device.id),
              isConnected: device.state == ConnectionState.connected,
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Reconnect log',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (hub.reconnectLog.isNotEmpty)
              TextButton(
                key: const Key('clear_reconnect_log_button'),
                onPressed: hub.clearReconnectLog,
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hub.reconnectLog.isEmpty)
          const _EmptyDiagnosticsHint(
            message: 'No reconnect attempts recorded yet.',
          )
        else
          _ReconnectLogCard(events: hub.reconnectLog),
        const SizedBox(height: 24),
        Text(
          'Developer',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: FlowlogColors.cardElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
          ),
          child: ListTile(
            key: const Key('settings_try_demo'),
            leading: const Icon(Icons.science_outlined),
            title: const Text('Try demo shot'),
            subtitle: const Text(
              'Replay bundled sample data on the Live tab',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(startDemoShotFromSettings(context)),
          ),
        ),
      ],
    );
  }
}

/// Switches to Live and starts bundled demo replay (More → Sensor diagnostics).
Future<void> startDemoShotFromSettings(BuildContext context) async {
  final shortcuts = FlowlogShortcutsScope.maybeOf(context);
  final switchTab = FlowlogShellScope.maybeOf(context)?.switchTab;
  final startDemo = shortcuts?.registry.startDemoShot;
  if (switchTab == null || startDemo == null) {
    return;
  }

  Navigator.of(context).pop();
  switchTab(AppTab.live);
  await Future<void>.delayed(Duration.zero);
  await startDemo();
}

/// Opens [SensorDiagnosticsScreen] from Sensors or More.
void openSensorDiagnosticsScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Sensor diagnostics')),
        body: const SensorDiagnosticsScreen(),
      ),
    ),
  );
}

class _LastErrorCard extends StatelessWidget {
  const _LastErrorCard({required this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;

    return Card(
      key: const Key('last_error_card'),
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasError ? Icons.error_outline : Icons.check_circle_outline,
                  color: hasError ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Last error',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasError ? errorMessage! : 'No errors recorded',
              key: const Key('last_error_message'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasError
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({
    required this.deviceName,
    required this.percent,
    required this.isConnected,
  });

  final String deviceName;
  final int? percent;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLow = isPressensorLowBattery(percent);
    final display = percent == null
        ? (isConnected ? '— % (unavailable)' : 'Connect to read')
        : '$percent%';

    return Card(
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
        side: isLow
            ? BorderSide(color: scheme.error.withValues(alpha: 0.6))
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(
          isLow ? Icons.battery_alert : Icons.battery_std,
          color: isLow ? scheme.error : null,
        ),
        title: Text(deviceName),
        subtitle: Text(
          isLow ? '$display · Low battery' : 'Battery: $display',
          key: Key('battery_${deviceName}_value'),
          style: isLow
              ? TextStyle(color: scheme.error)
              : null,
        ),
      ),
    );
  }
}

class _RssiCard extends StatelessWidget {
  const _RssiCard({
    required this.deviceName,
    required this.rssi,
  });

  final String deviceName;
  final int? rssi;

  @override
  Widget build(BuildContext context) {
    final display = rssi == null ? '— dBm (placeholder)' : '$rssi dBm';

    return Card(
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
      ),
      child: ListTile(
        leading: const Icon(Icons.signal_cellular_alt),
        title: Text(deviceName),
        subtitle: Text(
          'RSSI: $display',
          key: Key('rssi_${deviceName}_value'),
        ),
      ),
    );
  }
}

class _ReconnectLogCard extends StatelessWidget {
  const _ReconnectLogCard({required this.events});

  final List<SensorReconnectEvent> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('reconnect_log_card'),
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final event = events[index];
          return _ReconnectLogTile(event: event);
        },
      ),
    );
  }
}

class _ReconnectLogTile extends StatelessWidget {
  const _ReconnectLogTile({required this.event});

  final SensorReconnectEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = _styleForOutcome(scheme, event.outcome);
    final time = _formatTimestamp(event.timestamp);

    return ListTile(
      key: Key('reconnect_event_${event.deviceId}_${event.timestamp.millisecondsSinceEpoch}'),
      dense: true,
      title: Text(event.deviceName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · $time'),
          if (event.message != null && event.message!.isNotEmpty)
            Text(
              event.message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
        ],
      ),
      trailing: Icon(
        _iconForOutcome(event.outcome),
        color: color,
        size: 20,
      ),
    );
  }

  (String, Color) _styleForOutcome(ColorScheme scheme, ReconnectOutcome outcome) {
    return switch (outcome) {
      ReconnectOutcome.attempted => (
          'Attempted',
          scheme.onSurfaceVariant,
        ),
      ReconnectOutcome.connected => (
          'Connected',
          scheme.primary,
        ),
      ReconnectOutcome.failed => (
          'Failed',
          scheme.error,
        ),
    };
  }

  IconData _iconForOutcome(ReconnectOutcome outcome) {
    return switch (outcome) {
      ReconnectOutcome.attempted => Icons.sync,
      ReconnectOutcome.connected => Icons.bluetooth_connected,
      ReconnectOutcome.failed => Icons.bluetooth_disabled,
    };
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}

class _EmptyDiagnosticsHint extends StatelessWidget {
  const _EmptyDiagnosticsHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}