import 'dart:async';
import 'dart:io';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/wifi_scale/wifi_scale.dart';
import 'package:test/test.dart';

void main() {
  group('parseWifiScaleWeightFrame', () {
    test('parses untyped grams/ms snapshot', () {
      expect(
        parseWifiScaleWeightFrame('{"grams": 25.66, "ms": 12345}'),
        const WifiScaleWeightFrame(grams: 25.66, deviceMs: 12345),
      );
    });

    test('ignores typed frames', () {
      expect(
        parseWifiScaleWeightFrame(
          '{"type": "status", "grams": 0.0, "ms": 1}',
        ),
        isNull,
      );
      expect(
        parseWifiScaleWeightFrame('{"type": "rate", "hz": 10, "ms": 1}'),
        isNull,
      );
    });

    test('returns null for invalid payloads', () {
      expect(parseWifiScaleWeightFrame(''), isNull);
      expect(parseWifiScaleWeightFrame('not json'), isNull);
      expect(parseWifiScaleWeightFrame('{"grams": "heavy"}'), isNull);
      expect(parseWifiScaleWeightFrame('[]'), isNull);
    });
  });

  group('WifiScaleCommands', () {
    test('exposes documented tare commands', () {
      expect(WifiScaleCommands.tareText, 'tare');
      expect(WifiScaleCommands.tareJson(), '{"command":"tare"}');
      expect(WifiScaleCommands.rate('10k'), 'rate 10k');
    });
  });

  group('WifiScaleConstants', () {
    test('builds snapshot websocket URI', () {
      expect(
        WifiScaleConstants.websocketUri(),
        Uri.parse('ws://hds.local/snapshot'),
      );
      expect(
        WifiScaleConstants.websocketUri(host: '192.168.1.50'),
        Uri.parse('ws://192.168.1.50/snapshot'),
      );
    });
  });

  group('WifiScaleAdapter', () {
    late MockWifiScaleTransport transport;
    late WifiScaleAdapter adapter;
    late int clockMs;

    setUp(() {
      clockMs = 5_000;
      transport = MockWifiScaleTransport();
      adapter = WifiScaleAdapter(
        transport: transport,
        host: '192.168.1.50',
        monotonicClock: () => clockMs,
      );
    });

    tearDown(() async {
      await adapter.disconnect();
    });

    test('connect negotiates rate and reaches connected state', () async {
      final states = <ConnectionState>[];
      final sub = adapter.state.listen(states.add);

      await adapter.connect();
      await Future<void>.delayed(Duration.zero);

      expect(transport.connected, isTrue);
      expect(adapter.sentCommands, [WifiScaleConstants.defaultRateCommand]);
      expect(states, [ConnectionState.connecting, ConnectionState.connected]);

      await sub.cancel();
    });

    test('tare sends legacy text command', () async {
      await adapter.connect();
      await adapter.tare();

      expect(adapter.sentCommands.last, WifiScaleCommands.tareText);
    });

    test('emits weight samples stamped with host receive time', () async {
      final samples = <SensorSample>[];
      final sub = adapter.samples.listen(samples.add);

      await adapter.connect();
      clockMs = 5_250;
      transport.emitMessage('{"grams": 18.4, "ms": 9900}');
      await Future<void>.delayed(Duration.zero);

      expect(samples, hasLength(1));
      expect(samples.single.weightG, 18.4);
      expect(samples.single.elapsedMs, 250);

      await sub.cancel();
    });

    test('ignores typed status frames', () async {
      final samples = <SensorSample>[];
      final sub = adapter.samples.listen(samples.add);

      await adapter.connect();
      transport.emitMessage(
        '{"type": "status", "grams": 0.0, "ms": 1, "battery_percent": 80}',
      );
      await Future<void>.delayed(Duration.zero);

      expect(samples, isEmpty);

      await sub.cancel();
    });

    test('disconnect emits disconnected and stops samples', () async {
      final states = <ConnectionState>[];
      final sub = adapter.state.listen(states.add);

      await adapter.connect();
      await adapter.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states.last, ConnectionState.disconnected);
      expect(transport.connected, isFalse);

      await sub.cancel();
    });
  });

  group('WifiScaleAdapter integration', () {
    test(
      'connects to LAN scale when FLOWLOG_WIFI_SCALE=1',
      () async {
        final host = Platform.environment['HDS_HOST'] ?? 'hds.local';
        final transport = WebSocketWifiScaleTransport();
        final adapter = WifiScaleAdapter(transport: transport, host: host);

        await adapter.connect();
        final sample = await adapter.samples.first.timeout(
          const Duration(seconds: 8),
        );
        await adapter.disconnect();

        expect(sample.weightG, isNotNull);
      },
      skip: Platform.environment['FLOWLOG_WIFI_SCALE'] != '1'
          ? 'Set FLOWLOG_WIFI_SCALE=1'
          : false,
      tags: ['wifi'],
    );
  });
}