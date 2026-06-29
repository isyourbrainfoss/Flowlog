import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;

/// Placeholder paired device entry for the device manager stub.
class PairedSensorDevice {
  const PairedSensorDevice({
    required this.name,
    required this.kind,
    required this.connectionState,
  });

  final String name;
  final String kind;
  final ConnectionState connectionState;
}

/// Mock paired sensors until real BLE pairing is wired up.
const List<PairedSensorDevice> kMockPairedDevices = [
  PairedSensorDevice(
    name: 'Pressensor PRS',
    kind: 'Pressure sensor',
    connectionState: ConnectionState.connected,
  ),
  PairedSensorDevice(
    name: 'Decent Scale',
    kind: 'BLE scale',
    connectionState: ConnectionState.disconnected,
  ),
];

/// Device manager stub: placeholder list of paired sensors with mock states.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({
    super.key,
    this.devices = kMockPairedDevices,
  });

  final List<PairedSensorDevice> devices;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Paired devices',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final device in devices) ...[
          _PairedDeviceCard(device: device),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _PairedDeviceCard extends StatelessWidget {
  const _PairedDeviceCard({required this.device});

  final PairedSensorDevice device;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _iconForDevice(device.name),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.kind,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            ConnectionStateChip(state: device.connectionState),
          ],
        ),
      ),
    );
  }

  IconData _iconForDevice(String name) {
    if (name.contains('Scale')) {
      return Icons.scale;
    }
    return Icons.speed;
  }
}

/// Compact chip showing a sensor [ConnectionState] with Flowlog palette tokens.
class ConnectionStateChip extends StatelessWidget {
  const ConnectionStateChip({super.key, required this.state});

  final ConnectionState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, background, foreground) = _styleForState(scheme, state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  (String, Color, Color) _styleForState(ColorScheme scheme, ConnectionState state) {
    return switch (state) {
      ConnectionState.connected => (
          'Connected',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      ConnectionState.disconnected => (
          'Disconnected',
          scheme.surface,
          scheme.onSurfaceVariant,
        ),
      ConnectionState.connecting => (
          'Connecting',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      ConnectionState.error => (
          'Error',
          scheme.error.withValues(alpha: 0.16),
          scheme.error,
        ),
    };
  }
}