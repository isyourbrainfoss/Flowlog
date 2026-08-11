// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart' hide ConnectionState;

/// Builds a [PressensorBleAdapter] for a paired pressensor device.
typedef PressureAdapterFactory = PressensorBleAdapter Function(
  PairedSensorEntry device,
);

/// Builds a [DecentScaleBleAdapter] for a paired scale device.
typedef WeightAdapterFactory = DecentScaleBleAdapter Function(
  PairedSensorEntry device,
);

/// Sensor adapter that connects successfully but never emits samples.
class IdleSensorAdapter implements SensorAdapter {
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  @override
  Future<void> connect() async {
    _stateController.add(ConnectionState.connecting);
    _stateController.add(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _stateController.add(ConnectionState.disconnected);
  }
}

/// [SensorAdapter] wrapper around [MergedSampleStream] for [LiveShotController].
class MergedSampleStreamAdapter implements SensorAdapter {
  MergedSampleStreamAdapter({required MergedSampleStream merged})
      : _merged = merged;

  final MergedSampleStream _merged;
  final _stateController = StreamController<ConnectionState>.broadcast();

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _merged.samples;

  @override
  Future<void> connect() async {
    _stateController.add(ConnectionState.connecting);
    await _merged.start();
    _stateController.add(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    await _merged.stop();
    _stateController.add(ConnectionState.disconnected);
  }

  Future<void> dispose() async {
    await _merged.dispose();
    await _stateController.close();
  }
}

/// Resolves the active [SensorAdapter] when [connect] is called.
class SessionSensorAdapter implements SensorAdapter {
  SessionSensorAdapter({required this.resolve});

  final SensorAdapter Function() resolve;

  SensorAdapter? _delegate;
  StreamSubscription<ConnectionState>? _stateSub;
  StreamSubscription<SensorSample>? _samplesSub;
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  @override
  Future<void> connect() async {
    // Tear down any half-open prior session so reconnect after a failed start
    // does not leave double subscriptions.
    await disconnect();
    final adapter = resolve();
    _delegate = adapter;
    _stateSub = adapter.state.listen(_stateController.add);
    _samplesSub = adapter.samples.listen(_samplesController.add);
    try {
      await adapter.connect();
    } on Object {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final delegate = _delegate;
    _delegate = null;
    await _stateSub?.cancel();
    await _samplesSub?.cancel();
    _stateSub = null;
    _samplesSub = null;
    if (delegate != null) {
      try {
        // Bound BLE teardown so Start cannot hang forever.
        await delegate.disconnect().timeout(const Duration(seconds: 2));
      } on Object {
        // ignore adapter disconnect errors so start recovery can continue
      }
      if (delegate is MergedSampleStreamAdapter) {
        try {
          await delegate.dispose().timeout(const Duration(seconds: 1));
        } on Object {
          // ignore
        }
      }
    }
    if (!_stateController.isClosed) {
      _stateController.add(ConnectionState.disconnected);
    }
  }
}

/// Chooses the Live tab sample source from [SensorHub] state and demo mode.
class LiveSensorSource {
  LiveSensorSource({
    required this.hub,
    this.demoFixturePath,
    this.demoFixtureLoader,
    this.pressureAdapterFactory,
    this.weightAdapterFactory,
  });

  final SensorHub hub;
  final String? demoFixturePath;
  final Future<List<SensorSample>> Function()? demoFixtureLoader;
  final PressureAdapterFactory? pressureAdapterFactory;
  final WeightAdapterFactory? weightAdapterFactory;

  bool _demoMode = false;

  bool get isDemoMode => _demoMode;

  void enterDemoMode() {
    _demoMode = true;
  }

  void exitDemoMode() {
    _demoMode = false;
  }

  /// Whether any paired sensor is currently connected.
  bool get hasConnectedSensors => hub.devices.any(
        (device) => device.state == ConnectionState.connected,
      );

  /// Adapter used for the next live shot session.
  SensorAdapter resolveSampleAdapter() {
    if (_demoMode) {
      return MockReplayAdapter(
        fixturePath: demoFixturePath,
        fixtureLoader: demoFixtureLoader,
        speed: 1.0,
      );
    }

    final pressureAdapter = _resolvePressureAdapter();
    final scaleAdapter = _resolveScaleAdapter();

    if (pressureAdapter == null && scaleAdapter == null) {
      return IdleSensorAdapter();
    }

    final usesHubAdapters =
        hub.activeAdapterFor(SensorKind.pressensor) != null ||
        hub.activeAdapterFor(SensorKind.scale) != null;

    return MergedSampleStreamAdapter(
      merged: MergedSampleStream(
        pressureAdapter: pressureAdapter,
        weightAdapter: scaleAdapter,
        manageAdapterLifecycle: !usesHubAdapters,
      ),
    );
  }

  /// Re-arms the weight stream and tares before a brew.
  ///
  /// Call after the session sample merge is already listening so the first
  /// post-tare packets are not dropped. LED-on then tare matches Decent /
  /// Flowlog DIY scale expectations.
  Future<void> onTare() async {
    if (_demoMode) {
      return;
    }

    final hubScale = hub.activeAdapterFor(SensorKind.scale);
    if (hubScale is DecentScaleBleAdapter) {
      await _prepareDecentScale(hubScale);
      return;
    }

    final scaleDevice = _connectedDevice(SensorKind.scale);
    if (scaleDevice == null) {
      return;
    }

    final factory = weightAdapterFactory;
    if (factory == null) {
      return;
    }

    await _prepareDecentScale(factory(scaleDevice));
  }

  Future<void> _prepareDecentScale(DecentScaleBleAdapter scale) async {
    // Always re-assert LED-on so FFF4 weight notifies resume. A "connected"
    // hub link with a quiet notify stream shows "—" weight mid-brew.
    try {
      await scale.ledOn();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await scale.tare();
    } on Object {
      try {
        await scale.ledOn();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await scale.tare();
      } on Object {
        rethrow;
      }
    }
  }

  /// Re-arms weight notifications (and LED-on) without taring mid-shot.
  Future<void> rearmWeightStream() async {
    if (_demoMode) {
      return;
    }
    final scale = _connectedScaleAdapter();
    if (scale == null) {
      // Try hub-level reconnect of the paired scale only.
      for (final device in hub.devices) {
        if (device.kind == SensorKind.scale &&
            device.bleRemoteId != null &&
            device.bleRemoteId!.isNotEmpty) {
          unawaited(hub.connect(device.id));
          break;
        }
      }
      return;
    }
    try {
      await scale.rearmStream();
    } on Object {
      try {
        await scale.ledOn();
      } on Object {
        // Best-effort.
      }
    }
  }

  /// True when a scale is paired and the hub reports it connected.
  bool get scaleLinkConnected {
    if (_demoMode) {
      return false;
    }
    return hub.scaleState == ConnectionState.connected &&
        hub.hasKind(SensorKind.scale);
  }

  /// True when a scale is paired (any link state).
  bool get scalePaired => hub.hasKind(SensorKind.scale);

  DecentScaleBleAdapter? _connectedScaleAdapter() {
    if (_demoMode) {
      return null;
    }
    final hubScale = hub.activeAdapterFor(SensorKind.scale);
    if (hubScale is DecentScaleBleAdapter) {
      return hubScale;
    }
    return null;
  }

  /// Pushes OLED display config (target/warn/pressure window) to the DIY scale.
  Future<void> pushScaleDisplayConfig({
    required int targetYieldG,
    required int warnAtG,
    required int pressureMinBar,
    required int pressureMaxBar,
  }) async {
    final scale = _connectedScaleAdapter();
    if (scale == null) {
      return;
    }
    try {
      await scale.sendScaleDisplayConfig(
        targetYieldG: targetYieldG,
        warnAtG: warnAtG,
        pressureMinBar: pressureMinBar,
        pressureMaxBar: pressureMaxBar,
      );
    } on Object {
      // Best-effort — older firmwares ignore 0xF3.
    }
  }

  /// Tells the DIY scale an app brew started (frees PRS, shows phone pressure).
  Future<void> onPhoneBrewStart() async {
    final scale = _connectedScaleAdapter();
    if (scale == null) {
      return;
    }
    try {
      await scale.sendPhoneBrewStart();
    } on Object {
      // Best-effort — older firmwares ignore 0xF1.
    }
  }

  /// Tells the DIY scale the app brew ended.
  Future<void> onPhoneBrewEnd() async {
    final scale = _connectedScaleAdapter();
    if (scale == null) {
      return;
    }
    try {
      await scale.sendPhoneBrewEnd();
    } on Object {
      // Best-effort.
    }
  }

  int _lastPressureForwardMs = 0;

  /// Forwards live pressensor bar to the scale OLED (throttled ~2 Hz).
  ///
  /// Kept well below the weight notify rate so BLE writes never crowd out
  /// FFF4 weight packets mid-brew.
  Future<void> forwardPressure(double pressureBar) async {
    final scale = _connectedScaleAdapter();
    if (scale == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPressureForwardMs < 500) {
      return;
    }
    _lastPressureForwardMs = now;
    try {
      await scale.sendPhonePressure(pressureBar);
    } on Object {
      // Best-effort.
    }
  }

  SensorAdapter? _resolvePressureAdapter() {
    final hubAdapter = hub.activeAdapterFor(SensorKind.pressensor);
    if (hubAdapter != null) {
      return hubAdapter;
    }

    final device = _connectedDevice(SensorKind.pressensor);
    if (device == null) {
      return null;
    }

    final factory = pressureAdapterFactory;
    if (factory == null) {
      return null;
    }

    return factory(device);
  }

  SensorAdapter? _resolveScaleAdapter() {
    final hubAdapter = hub.activeAdapterFor(SensorKind.scale);
    if (hubAdapter != null) {
      return hubAdapter;
    }

    final device = _connectedDevice(SensorKind.scale);
    if (device == null) {
      return null;
    }

    final factory = weightAdapterFactory;
    if (factory == null) {
      return null;
    }

    return factory(device);
  }

  PairedSensorEntry? _connectedDevice(SensorKind kind) {
    for (final device in hub.devices) {
      if (device.kind == kind && device.state == ConnectionState.connected) {
        return device;
      }
    }
    return null;
  }
}

/// Banner shown on Live while a demo replay session is active.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Demo shot — replayed sample data',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              key: const Key('demo_mode_dismiss'),
              tooltip: 'Exit demo mode',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}