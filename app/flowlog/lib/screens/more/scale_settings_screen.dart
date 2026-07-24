import 'dart:async';

import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/settings/scale_settings_store.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' as fls
    show ConnectionState, DecentScaleBleAdapter;
import 'package:flutter/material.dart';

/// Configure Flowlog DIY scale OLED cues and push them over BLE when connected.
class ScaleSettingsScreen extends StatefulWidget {
  const ScaleSettingsScreen({
    super.key,
    this.store,
    this.hub,
  });

  final ScaleSettingsStore? store;
  final SensorHub? hub;

  @override
  State<ScaleSettingsScreen> createState() => _ScaleSettingsScreenState();
}

class _ScaleSettingsScreenState extends State<ScaleSettingsScreen> {
  late final ScaleSettingsStore _store;
  ScaleDisplaySettings _settings = const ScaleDisplaySettings();
  bool _loading = true;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? ScaleSettingsStore();
    unawaited(_load());
  }

  Future<void> _load() async {
    final s = await _store.load();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _save({bool push = true}) async {
    setState(() {
      _saving = true;
      _status = null;
    });
    var s = _settings;
    if (s.warnAtG > s.targetYieldG) {
      s = s.copyWith(warnAtG: s.targetYieldG);
    }
    if (s.pressureMaxBar <= s.pressureMinBar) {
      s = s.copyWith(pressureMaxBar: s.pressureMinBar + 1);
    }
    await _store.save(s);
    var message = 'Saved on phone';
    if (push) {
      final ok = await _pushToScale(s);
      message = ok
          ? 'Saved and sent to scale'
          : 'Saved — connect the scale to push (or retry)';
    }
    if (!mounted) return;
    setState(() {
      _settings = s;
      _saving = false;
      _status = message;
    });
  }

  Future<bool> _pushToScale(ScaleDisplaySettings s) async {
    final hub = widget.hub ?? SensorHubScope.maybeOf(context);
    if (hub == null) {
      return false;
    }
    final adapter = hub.activeAdapterFor(SensorKind.scale);
    if (adapter is! fls.DecentScaleBleAdapter) {
      return false;
    }
    try {
      await adapter.sendScaleDisplayConfig(
        targetYieldG: s.targetYieldG.round(),
        warnAtG: s.warnAtG.round(),
        pressureMinBar: s.pressureMinBar.round(),
        pressureMaxBar: s.pressureMaxBar.round(),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hub = widget.hub ?? SensorHubScope.maybeOf(context);
    final scaleConnected = hub?.scaleState == fls.ConnectionState.connected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'These values drive the scale OLED cup target, soft wind-back chirp, '
          'and pressure bar window for phone-free brews. They are also pushed '
          'when you start an app brew if the scale is connected.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            scaleConnected
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: scaleConnected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(
            scaleConnected ? 'Scale connected' : 'Scale not connected',
          ),
          subtitle: Text(
            scaleConnected
                ? 'Save will push settings over BLE'
                : 'Pair/connect the scale under Sensors first',
          ),
        ),
        const Divider(),
        Text('Cup target', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          key: const Key('scale_settings_target_slider'),
          value: _settings.targetYieldG.clamp(15, 60),
          min: 15,
          max: 60,
          divisions: 45,
          label: '${_settings.targetYieldG.round()} g',
          onChanged: (v) => setState(() {
            _settings = _settings.copyWith(targetYieldG: v.roundToDouble());
          }),
        ),
        Text(
          'Target ${_settings.targetYieldG.round()} g',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text('Wind-back warn', style: Theme.of(context).textTheme.titleSmall),
        Slider(
          key: const Key('scale_settings_warn_slider'),
          value: _settings.warnAtG.clamp(10, 60),
          min: 10,
          max: 60,
          divisions: 50,
          label: '${_settings.warnAtG.round()} g',
          onChanged: (v) => setState(() {
            _settings = _settings.copyWith(warnAtG: v.roundToDouble());
          }),
        ),
        Text(
          'Soft chime at ${_settings.warnAtG.round()} g',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Pressure bar range',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider(
          key: const Key('scale_settings_pmin_slider'),
          value: _settings.pressureMinBar.clamp(0, 12),
          min: 0,
          max: 12,
          divisions: 12,
          label: '${_settings.pressureMinBar.round()} bar min',
          onChanged: (v) => setState(() {
            _settings = _settings.copyWith(pressureMinBar: v.roundToDouble());
          }),
        ),
        Slider(
          key: const Key('scale_settings_pmax_slider'),
          value: _settings.pressureMaxBar.clamp(1, 15),
          min: 1,
          max: 15,
          divisions: 14,
          label: '${_settings.pressureMaxBar.round()} bar max',
          onChanged: (v) => setState(() {
            _settings = _settings.copyWith(pressureMaxBar: v.roundToDouble());
          }),
        ),
        Text(
          '${_settings.pressureMinBar.round()} – ${_settings.pressureMaxBar.round()} bar on OLED',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('scale_settings_save_button'),
          onPressed: _saving ? null : () => unawaited(_save()),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving…' : 'Save & push to scale'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(
            _status!,
            key: const Key('scale_settings_status'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
