import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;

/// Sensors pairing and connection management.
class SensorsScreen extends StatelessWidget {
  const SensorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = SensorHubScope.of(context);
    final devices = hub.devices;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Sensors',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Pair your Pressensor and scale here. Live BLE connection is coming '
          'soon — use mock replay on the Live tab until then.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        if (devices.isEmpty)
          const _EmptySensorsState()
        else ...[
          Text(
            'Paired devices',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          for (final device in devices) ...[
            _PairedDeviceCard(
              device: device,
              onConnect: () => _connect(context, hub, device.id),
              onRemove: () => hub.removeDevice(device.id),
            ),
            const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 8),
        _AddSensorButtons(hub: hub),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('open_diagnostics_button'),
          onPressed: () => openSensorDiagnosticsScreen(context),
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Sensor diagnostics'),
        ),
      ],
    );
  }

  Future<void> _connect(
    BuildContext context,
    SensorHub hub,
    String deviceId,
  ) async {
    await hub.connect(deviceId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'BLE pairing UI is not wired yet. Sensor parsers are ready — '
          'hardware connect lands in the next slice.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _EmptySensorsState extends StatelessWidget {
  const _EmptySensorsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: FlowlogColors.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No sensors paired',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Add your Pressensor and scale below.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSensorButtons extends StatelessWidget {
  const _AddSensorButtons({required this.hub});

  final SensorHub hub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('add_pressensor_button'),
          onPressed: hub.hasKind(SensorKind.pressensor)
              ? null
              : () => _add(context, SensorKind.pressensor),
          icon: const Icon(Icons.speed),
          label: const Text('Add Pressensor'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('add_scale_button'),
          onPressed:
              hub.hasKind(SensorKind.scale) ? null : () => _add(context, SensorKind.scale),
          icon: const Icon(Icons.scale),
          label: const Text('Add scale'),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, SensorKind kind) async {
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _AddSensorDialog(kind: kind),
    );
    if (name == null || !context.mounted) {
      return;
    }

    final added = hub.addDevice(kind, name: name);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A ${kind.defaultName} is already paired.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _AddSensorDialog extends StatefulWidget {
  const _AddSensorDialog({required this.kind});

  final SensorKind kind;

  @override
  State<_AddSensorDialog> createState() => _AddSensorDialogState();
}

class _AddSensorDialogState extends State<_AddSensorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.kind.defaultName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.kind.defaultName}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Device name',
          hintText: widget.kind.defaultName,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _PairedDeviceCard extends StatelessWidget {
  const _PairedDeviceCard({
    required this.device,
    required this.onConnect,
    required this.onRemove,
  });

  final PairedSensorEntry device;
  final VoidCallback onConnect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final canConnect = device.state == ConnectionState.disconnected ||
        device.state == ConnectionState.error;

    return Card(
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
                  device.kind.icon,
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
                        device.kind.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                ConnectionStateChip(state: device.state),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: canConnect ? onConnect : null,
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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