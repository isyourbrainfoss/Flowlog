import 'dart:async';

import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/settings/auto_start_settings_store.dart';
import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, isPressensorLowBattery, pressensorLowBatteryWarning;
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
          'Pair your Pressensor and scale here. Flowlog scans automatically '
          'after you add a sensor, then connect when hardware is nearby.',
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
              hub: hub,
              device: device,
              onConnect: () => _connect(context, hub, device.id),
              onDisconnect: () => _disconnect(context, hub, device.id),
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

  Future<void> _disconnect(
    BuildContext context,
    SensorHub hub,
    String deviceId,
  ) async {
    final device = hub.devices.firstWhere((entry) => entry.id == deviceId);
    await hub.disconnect(deviceId);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Disconnected from ${device.name}. Another device can connect now.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
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
    final message = await _connectMessage(hub: hub, device: device);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<String> _connectMessage({
  required SensorHub hub,
  required PairedSensorEntry device,
}) async {
  return switch (device.state) {
    ConnectionState.connected => device.kind == SensorKind.pressensor
        ? _pressensorConnectedMessage(device.name, hub)
        : 'Connected to ${device.name}.',
    ConnectionState.connecting => 'Connecting to ${device.name}…',
    _ => hub.lastError ??
        'Could not connect to ${device.name}. Check Bluetooth and try again.',
  };
}

Future<String> _pressensorConnectedMessage(
  String deviceName,
  SensorHub hub,
) async {
  final settings = await AutoStartSettingsStore().load();
  final buffer = StringBuffer(
    'Connected to $deviceName. Auto-start at '
    '${settings.startThresholdBar.toStringAsFixed(1)} bar.',
  );
  final batteryWarning = pressensorLowBatteryWarning(hub.pressensorBatteryPercent);
  if (batteryWarning != null) {
    buffer.write(' $batteryWarning');
  }
  return buffer.toString();
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
      await _runSensorScanFlow(context, hub, kind);
    }
  }
}

Future<void> _runSensorScanFlow(
  BuildContext context,
  SensorHub hub,
  SensorKind kind,
) async {
  // Captured before awaits; safe for post-await use of the navigator/messenger objects.
  // ignore: use_build_context_synchronously
  final messenger = ScaffoldMessenger.of(context);
  // ignore: use_build_context_synchronously
  final navigator = Navigator.of(context, rootNavigator: true);

  // Capture a context tied to the progress dialog itself so we can dismiss reliably
  // even if the caller's context unmounts or navigator references drift.
  BuildContext? dialogContext;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) {
        dialogContext = dctx;
        return AlertDialog(
          key: Key('scan_progress_${kind.name}'),
          title: Text('Scanning for ${kind.defaultName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Keep ${kind.defaultName} powered on and nearby.',
                style: Theme.of(dctx).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    ),
  );

  // Yield once so that even when the subsequent scan is synchronous (as in tests with
  // stub backends), the showDialog has a chance to run its builder and insert the route.
  // In real usage with an 8s BLE scan this is imperceptible.
  await Future<void>.delayed(Duration.zero);

  BleScanAssignResult result;
  try {
    result = await hub.scanAndAssign(kind);
  } catch (e) {
    hub.setLastError('Scan failed: $e');
    result = BleScanAssignResult.unavailable('Scan error: $e');
  } finally {
    // Only pop if we have the dialog's own context (meaning the route was inserted).
    // Never fall back to an unconditional pop on the navigator here — doing so while
    // the progress dialog hasn't been pushed yet would pop the parent route (e.g. the
    // sensors page), invalidating the caller's context for later showDialog calls.
    final dc = dialogContext;
    if (dc != null) {
      try {
        // dc originates from the progress dialog builder (pre-await); using after the
        // scan await is the standard way to dismiss your own dialog.
        // ignore: use_build_context_synchronously
        if (Navigator.canPop(dc)) {
          // ignore: use_build_context_synchronously
          Navigator.pop(dc);
        }
      } catch (_) {}
    }
  }
  // ignore: use_build_context_synchronously
  if (!context.mounted && !navigator.mounted) {
    return;
  }
  // The navigator was captured pre-await above; using its .context and .mounted after
  // the scan await is intentional and guarded.

  // Use the navigator captured *before* awaits for follow-up dialogs. This context
  // is tied to the root navigator and survives even if the caller's widget context
  // becomes invalid after async gaps (common gotcha after awaiting in dialog flows).
  final dialogNavContext = navigator.context;

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
      await showDialog<void>(
        context: dialogNavContext,
        builder: (dialogContext) => AlertDialog(
          key: const Key('scan_not_found_dialog'),
          title: const Text('Sensor not found'),
          content: Text(
            'No nearby ${kind.defaultName} was detected. Power it on, '
            'stay within range, then tap Scan again.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    case BleScanAssignOutcome.multiple:
      final selected = await showDialog<BleDiscoveredDevice>(
        context: dialogNavContext,
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
      await showDialog<void>(
        context: dialogNavContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bluetooth unavailable'),
          content: Text(
            result.message ?? 'Bluetooth is not available on this device.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
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
          separatorBuilder: (context, index) => const Divider(height: 1),
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
    required this.hub,
    required this.device,
    required this.onConnect,
    required this.onDisconnect,
    required this.onScan,
    required this.onRemove,
  });

  final SensorHub hub;
  final PairedSensorEntry device;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onScan;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final canConnect = device.state == ConnectionState.disconnected ||
        device.state == ConnectionState.error;
    final canDisconnect = device.state == ConnectionState.connected;
    final batteryPercent = device.kind == SensorKind.pressensor
        ? hub.batteryPercentFor(device.id)
        : null;
    final batteryIsLow = isPressensorLowBattery(batteryPercent);

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
            if (batteryPercent != null &&
                device.state == ConnectionState.connected) ...[
              Text(
                batteryIsLow
                    ? 'Battery: $batteryPercent% · Low — charge soon'
                    : 'Battery: $batteryPercent%',
                key: Key('paired_battery_${device.id}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: batteryIsLow
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canConnect)
                  FilledButton.tonal(
                    key: Key('connect_${device.id}'),
                    onPressed: onConnect,
                    child: const Text('Connect'),
                  ),
                if (canDisconnect)
                  FilledButton.tonal(
                    key: Key('disconnect_${device.id}'),
                    onPressed: onDisconnect,
                    child: const Text('Disconnect'),
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