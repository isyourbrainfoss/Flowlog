import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/sensors/ble_transport.dart';
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
          'Pair your Pressensor and scale here. Scan after adding to capture '
          'the BLE device id, then connect when hardware is nearby.',
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
              onScan: () => _runSensorScanFlow(context, hub, device.kind),
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

    final device = hub.devices.firstWhere((entry) => entry.id == deviceId);
    final message = switch (device.state) {
      ConnectionState.connected => 'Connected to ${device.name}.',
      ConnectionState.connecting => 'Connecting to ${device.name}…',
      _ => hub.lastError ??
          'Could not connect to ${device.name}. Check Bluetooth and try again.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      return;
    }

    if (context.mounted) {
      await _offerScanAfterAdd(context, hub, kind);
    }
  }
}

Future<void> _offerScanAfterAdd(
  BuildContext context,
  SensorHub hub,
  SensorKind kind,
) async {
  final shouldScan = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _ScanAfterAddDialog(kind: kind),
  );
  if (shouldScan != true || !context.mounted) {
    return;
  }

  await _runSensorScanFlow(context, hub, kind);
}

Future<void> _runSensorScanFlow(
  BuildContext context,
  SensorHub hub,
  SensorKind kind,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text('Scanning for ${kind.defaultName}…'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );

  final result = await hub.scanAndAssign(kind);
  if (!context.mounted) {
    return;
  }

  switch (result.outcome) {
    case BleScanAssignOutcome.assigned:
      final device = result.device!;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Assigned ${device.name} (${device.remoteId}).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    case BleScanAssignOutcome.notFound:
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No nearby sensor found. Power it on and tap Scan to try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    case BleScanAssignOutcome.multiple:
      final selected = await showDialog<BleDiscoveredDevice>(
        context: context,
        builder: (dialogContext) =>
            _PickScannedDeviceDialog(devices: result.devices),
      );
      if (selected != null) {
        hub.assignBleRemoteId(
          kind,
          bleRemoteId: selected.remoteId,
          name: selected.name,
          rssi: selected.rssi,
        );
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Assigned ${selected.name} (${selected.remoteId}).',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    case BleScanAssignOutcome.unavailable:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Bluetooth is not available on this device.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _ScanAfterAddDialog extends StatelessWidget {
  const _ScanAfterAddDialog({required this.kind});

  final SensorKind kind;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Scan for ${kind.defaultName}?'),
      content: Text(
        'Look for a nearby ${kind.defaultName} and assign its BLE device id '
        'automatically.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Skip'),
        ),
        FilledButton(
          key: const Key('scan_after_add_button'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Scan'),
        ),
      ],
    );
  }
}

class _PickScannedDeviceDialog extends StatelessWidget {
  const _PickScannedDeviceDialog({required this.devices});

  final List<BleDiscoveredDevice> devices;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose sensor'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final device = devices[index];
            return ListTile(
              title: Text(device.name),
              subtitle: Text('${device.remoteId} · ${device.rssi} dBm'),
              onTap: () => Navigator.pop(context, device),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
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
    required this.onScan,
    required this.onRemove,
  });

  final PairedSensorEntry device;
  final VoidCallback onConnect;
  final VoidCallback onScan;
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
            if (device.bleRemoteId != null) ...[
              Text(
                'BLE id: ${device.bleRemoteId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: canConnect ? onConnect : null,
                  child: const Text('Connect'),
                ),
                OutlinedButton(
                  key: Key('scan_${device.kind.name}_button'),
                  onPressed: onScan,
                  child: const Text('Scan'),
                ),
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