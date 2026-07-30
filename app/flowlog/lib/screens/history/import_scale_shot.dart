import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flowlog/settings/scale_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;

/// Default hosts tried when importing a phone-free brew from the DIY scale.
const kDefaultScaleShotHosts = <String>[
  'half-decent.local',
  'half-decent',
];

/// Summary of one stored shot on the scale (Wi‑Fi list or BLE sizes).
@immutable
class ScaleShotSummary {
  const ScaleShotSummary({
    required this.index,
    this.id,
    this.startedAt,
    this.samples,
    this.bytes,
    this.yieldG,
    this.path,
  });

  final int index;
  final String? id;
  final String? startedAt;
  final int? samples;
  final int? bytes;
  final double? yieldG;
  final String? path;

  factory ScaleShotSummary.fromJson(Map<String, dynamic> json) {
    return ScaleShotSummary(
      index: (json['index'] as num?)?.toInt() ?? 0,
      id: json['id'] as String?,
      startedAt: json['startedAt'] as String?,
      samples: (json['samples'] as num?)?.toInt(),
      bytes: (json['bytes'] as num?)?.toInt(),
      yieldG: (json['yieldG'] as num?)?.toDouble(),
      path: json['path'] as String?,
    );
  }
}

/// Result of listing shots on the scale.
@immutable
class ScaleShotList {
  const ScaleShotList({
    required this.shots,
    required this.host,
    this.max = 3,
  });

  final List<ScaleShotSummary> shots;
  final String host;
  final int max;
}

/// Normalizes user input: strip scheme, path, whitespace.
String normalizeScaleHost(String raw) {
  var h = raw.trim();
  if (h.isEmpty) return h;
  h = h.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
  final slash = h.indexOf('/');
  if (slash >= 0) {
    h = h.substring(0, slash);
  }
  return h.trim();
}

/// Fetches `/shots.json` then falls back to a single `/shot.json`.
Future<ScaleShotList> fetchShotListFromScale({
  List<String> hosts = kDefaultScaleShotHosts,
  String? preferredHost,
  http.Client? client,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  Object? lastError;

  final tried = <String>[];
  final ordered = <String>[
    if (preferredHost != null && preferredHost.trim().isNotEmpty)
      normalizeScaleHost(preferredHost),
    ...hosts.map(normalizeScaleHost),
  ];

  try {
    for (final host in ordered) {
      if (host.isEmpty || tried.contains(host)) continue;
      tried.add(host);

      try {
        final listUri = Uri.parse('http://$host/shots.json');
        final listResp = await httpClient.get(listUri).timeout(timeout);
        if (listResp.statusCode == 200) {
          final decoded = jsonDecode(listResp.body);
          if (decoded is Map<String, dynamic>) {
            final raw = decoded['shots'];
            final shots = <ScaleShotSummary>[];
            if (raw is List) {
              for (final item in raw) {
                if (item is Map<String, dynamic>) {
                  shots.add(ScaleShotSummary.fromJson(item));
                } else if (item is Map) {
                  shots.add(
                    ScaleShotSummary.fromJson(Map<String, dynamic>.from(item)),
                  );
                }
              }
            }
            unawaited(ScaleSettingsStore().saveImportHost(host));
            return ScaleShotList(
              shots: shots,
              host: host,
              max: (decoded['max'] as num?)?.toInt() ?? 3,
            );
          }
        }

        // Older firmware: only /shot.json
        final shotUri = Uri.parse('http://$host/shot.json');
        final shotResp = await httpClient.get(shotUri).timeout(timeout);
        if (shotResp.statusCode == 404) {
          lastError = StateError('No shot saved on scale yet ($host)');
          continue;
        }
        if (shotResp.statusCode != 200) {
          lastError = StateError(
            'Scale at $host returned HTTP ${shotResp.statusCode}',
          );
          continue;
        }
        final decoded = jsonDecode(shotResp.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('shot.json is not an object');
        }
        final shot = Shot.fromJson(decoded);
        unawaited(ScaleSettingsStore().saveImportHost(host));
        return ScaleShotList(
          host: host,
          shots: [
            ScaleShotSummary(
              index: 0,
              id: shot.id,
              startedAt: shot.startedAt.toUtc().toIso8601String(),
              samples: shot.samples.length,
              yieldG: shot.yieldG,
              path: '/shot.json',
            ),
          ],
        );
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on FormatException catch (e) {
        lastError = e;
      }
    }
    throw StateError(
      'Could not reach the scale.\n'
      'Tried: ${tried.join(', ')}\n\n'
      'mDNS (half-decent.local) often fails on phones.\n'
      '1. Open the scale’s web page and note the IP (OLED Wi‑Fi status).\n'
      '2. Enter that IP below (e.g. 192.168.50.3).\n'
      '3. Or use Import via Bluetooth if the scale is paired.\n\n'
      'Last error: $lastError',
    );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

/// Fetches one shot by age (0 = newest) from the scale.
Future<Shot> fetchShotFromScale({
  List<String> hosts = kDefaultScaleShotHosts,
  String? preferredHost,
  int age = 0,
  http.Client? client,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  Object? lastError;

  final tried = <String>[];
  final ordered = <String>[
    if (preferredHost != null && preferredHost.trim().isNotEmpty)
      normalizeScaleHost(preferredHost),
    ...hosts.map(normalizeScaleHost),
  ];

  final paths = age == 0
      ? <String>['/shot/$age.json', '/shot.json']
      : <String>['/shot/$age.json'];

  try {
    for (final host in ordered) {
      if (host.isEmpty || tried.contains(host)) continue;
      tried.add(host);
      for (final path in paths) {
        final uri = Uri.parse('http://$host$path');
        try {
          final response = await httpClient.get(uri).timeout(timeout);
          if (response.statusCode == 404) {
            lastError = StateError('No shot at $path on $host');
            continue;
          }
          if (response.statusCode != 200) {
            lastError = StateError(
              'Scale at $host$path returned HTTP ${response.statusCode}',
            );
            continue;
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('shot JSON is not an object');
          }
          unawaited(ScaleSettingsStore().saveImportHost(host));
          return Shot.fromJson(decoded);
        } on TimeoutException catch (e) {
          lastError = e;
        } on SocketException catch (e) {
          lastError = e;
        } on http.ClientException catch (e) {
          lastError = e;
        } on FormatException catch (e) {
          lastError = e;
        }
      }
    }
    throw StateError(
      'Could not download shot $age.\n'
      'Tried: ${tried.join(', ')}\n'
      'Last error: $lastError',
    );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

// ---------------------------------------------------------------------------
// BLE shot transfer (firmware ≥1.6, types 0xF4/0xF5/0xF6 on FFF4)
// ---------------------------------------------------------------------------

/// Lists stored shot sizes via BLE when a Decent Scale is connected/paired.
Future<ScaleShotList> fetchShotListFromScaleBle({
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isLinux)) {
    throw StateError('BLE import is only available on Android/Linux.');
  }
  final device = await _resolveScaleDevice();
  final session = await _ScaleBleSession.connect(device, timeout: timeout);
  try {
    final sizes = await session.requestList(timeout: timeout);
    final shots = <ScaleShotSummary>[
      for (var i = 0; i < sizes.length; i++)
        if (sizes[i] > 0)
          ScaleShotSummary(index: i, bytes: sizes[i], path: 'ble://$i'),
    ];
    // Also ask for IP to help the user fill the Wi‑Fi field later.
    final ip = await session.requestStatus(timeout: const Duration(seconds: 3));
    if (ip != null && ip.isNotEmpty && ip != 'no-wifi') {
      unawaited(ScaleSettingsStore().saveImportHost(ip));
    }
    return ScaleShotList(shots: shots, host: 'ble:${device.remoteId.str}');
  } finally {
    await session.dispose();
  }
}

/// Downloads one shot JSON over BLE (age 0 = newest).
Future<Shot> fetchShotFromScaleBle({
  int age = 0,
  Duration timeout = const Duration(seconds: 90),
}) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isLinux)) {
    throw StateError('BLE import is only available on Android/Linux.');
  }
  final device = await _resolveScaleDevice();
  final session = await _ScaleBleSession.connect(device, timeout: timeout);
  try {
    final jsonStr = await session.requestShot(age: age, timeout: timeout);
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('BLE shot JSON is not an object');
    }
    return Shot.fromJson(decoded);
  } finally {
    await session.dispose();
  }
}

Future<BluetoothDevice> _resolveScaleDevice() async {
  // Prefer an already-connected Decent Scale.
  final connected = FlutterBluePlus.connectedDevices;
  for (final d in connected) {
    final name = d.platformName.isNotEmpty ? d.platformName : d.advName;
    if (name.toLowerCase().contains('decent') ||
        name.toLowerCase().contains('half')) {
      return d;
    }
  }

  // System bonded / remembered devices.
  try {
    final system = await FlutterBluePlus.systemDevices([
      Guid(DecentScaleConstants.serviceUuid),
    ]);
    for (final d in system) {
      final name = d.platformName.isNotEmpty ? d.platformName : d.advName;
      if (name.toLowerCase().contains('decent')) {
        return d;
      }
    }
  } on Object {
    // ignore
  }

  // Short scan.
  final completer = Completer<BluetoothDevice>();
  late StreamSubscription<List<ScanResult>> sub;
  sub = FlutterBluePlus.onScanResults.listen((results) {
    for (final r in results) {
      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : r.device.platformName;
      if (name.toLowerCase().contains('decent')) {
        if (!completer.isCompleted) {
          completer.complete(r.device);
        }
      }
    }
  });
  try {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 6),
      androidUsesFineLocation: false,
    );
    final device = await completer.future.timeout(const Duration(seconds: 6));
    return device;
  } on TimeoutException {
    throw StateError(
      'No Decent Scale found over Bluetooth.\n'
      'Pair it under More → Sensors first, keep it nearby, then retry.',
    );
  } finally {
    await FlutterBluePlus.stopScan();
    await sub.cancel();
  }
}

class _ScaleBleSession {
  _ScaleBleSession({
    required this.device,
    required this.writeChar,
    required this.notifyChar,
  });

  final BluetoothDevice device;
  final BluetoothCharacteristic writeChar;
  final BluetoothCharacteristic notifyChar;
  StreamSubscription<List<int>>? _sub;
  final _packets = StreamController<List<int>>.broadcast();

  static Future<_ScaleBleSession> connect(
    BluetoothDevice device, {
    required Duration timeout,
  }) async {
    if (!device.isConnected) {
      try {
        await device.disconnect(timeout: 3);
      } on Object {
        // ignore
      }
      await device.connect(
        license: License.nonprofit,
        autoConnect: false,
        timeout: timeout,
      );
    }
    final services = await device.discoverServices();
    BluetoothCharacteristic? write;
    BluetoothCharacteristic? notify;
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == Guid(DecentScaleConstants.writeUuid)) {
          write = c;
        } else if (c.uuid == Guid(DecentScaleConstants.notifyUuid)) {
          notify = c;
        }
      }
    }
    if (write == null || notify == null) {
      throw StateError('Scale BLE characteristics not found.');
    }
    final session = _ScaleBleSession(
      device: device,
      writeChar: write,
      notifyChar: notify,
    );
    session._sub = notify.onValueReceived.listen(session._packets.add);
    device.cancelWhenDisconnected(session._sub!);
    await notify.setNotifyValue(true);
    // Ensure stream is running.
    try {
      await write.write(
        DecentScaleCommands.ledOnGrams(),
        withoutResponse: write.properties.writeWithoutResponse,
      );
    } on Object {
      // optional
    }
    return session;
  }

  Future<List<int>> requestList({required Duration timeout}) async {
    final sizes = List<int>.filled(3, 0);
    final done = Completer<List<int>>();
    late StreamSubscription<List<int>> sub;
    sub = _packets.stream.listen((data) {
      if (data.length >= 9 && data[0] == 0x03 && data[1] == 0xF4) {
        final count = data[2].clamp(0, 3);
        for (var i = 0; i < 3; i++) {
          final lo = data[3 + i * 2];
          final hi = data[4 + i * 2];
          sizes[i] = lo | (hi << 8);
        }
        if (!done.isCompleted) {
          done.complete(sizes.take(count).toList());
        }
      }
    });
    try {
      await writeChar.write(
        DecentScaleCommands.shotExportList(),
        withoutResponse: writeChar.properties.writeWithoutResponse,
      );
      return await done.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<String?> requestStatus({required Duration timeout}) async {
    final done = Completer<String>();
    late StreamSubscription<List<int>> sub;
    sub = _packets.stream.listen((data) {
      if (data.length >= 3 && data[0] == 0x03 && data[1] == 0xF6) {
        final n = data[2].clamp(0, data.length - 3);
        final ip = String.fromCharCodes(data.sublist(3, 3 + n));
        if (!done.isCompleted) done.complete(ip);
      }
    });
    try {
      await writeChar.write(
        DecentScaleCommands.shotExportStatus(),
        withoutResponse: writeChar.properties.writeWithoutResponse,
      );
      return await done.future.timeout(timeout);
    } on TimeoutException {
      return null;
    } finally {
      await sub.cancel();
    }
  }

  Future<String> requestShot({
    required int age,
    required Duration timeout,
  }) async {
    final buf = BytesBuilder(copy: false);
    final done = Completer<String>();
    late StreamSubscription<List<int>> sub;
    sub = _packets.stream.listen((data) {
      if (data.length < 8 || data[0] != 0x03 || data[1] != 0xF5) {
        return;
      }
      final last = (data[3] & 0x01) != 0;
      final payload = data.sublist(8);
      buf.add(payload);
      if (last && !done.isCompleted) {
        done.complete(utf8.decode(buf.takeBytes()));
      }
    });
    try {
      await writeChar.write(
        DecentScaleCommands.shotExportGet(age: age),
        withoutResponse: writeChar.properties.writeWithoutResponse,
      );
      return await done.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _packets.close();
  }
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

/// Dialog to import one or more phone-free shots from the DIY scale.
///
/// Returns the selected shots (may be empty only if cancelled → null).
Future<List<Shot>?> showImportScaleShotDialog(
  BuildContext context, {
  Future<ScaleShotList> Function({String? host})? fetchList,
  Future<Shot> Function({String? host, int age})? fetchShot,
  Future<ScaleShotList> Function()? fetchListBle,
  Future<Shot> Function({int age})? fetchShotBle,
}) {
  return showDialog<List<Shot>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ImportScaleShotDialog(
      fetchList: fetchList ??
          ({String? host}) => fetchShotListFromScale(preferredHost: host),
      fetchShot: fetchShot ??
          ({String? host, int age = 0}) =>
              fetchShotFromScale(preferredHost: host, age: age),
      fetchListBle: fetchListBle ?? fetchShotListFromScaleBle,
      fetchShotBle: fetchShotBle ??
          ({int age = 0}) => fetchShotFromScaleBle(age: age),
    ),
  );
}

class _ImportScaleShotDialog extends StatefulWidget {
  const _ImportScaleShotDialog({
    required this.fetchList,
    required this.fetchShot,
    required this.fetchListBle,
    required this.fetchShotBle,
  });

  final Future<ScaleShotList> Function({String? host}) fetchList;
  final Future<Shot> Function({String? host, int age}) fetchShot;
  final Future<ScaleShotList> Function() fetchListBle;
  final Future<Shot> Function({int age}) fetchShotBle;

  @override
  State<_ImportScaleShotDialog> createState() => _ImportScaleShotDialogState();
}

class _ImportScaleShotDialogState extends State<_ImportScaleShotDialog> {
  bool _loading = true;
  bool _importing = false;
  String? _error;
  ScaleShotList? _list;
  final Set<int> _selected = {};
  late final TextEditingController _hostController;
  bool _viaBle = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final saved = await ScaleSettingsStore().loadImportHost();
    if (saved != null && mounted) {
      _hostController.text = saved;
    }
    await _loadWifi();
  }

  Future<void> _loadWifi() async {
    setState(() {
      _loading = true;
      _error = null;
      _list = null;
      _selected.clear();
      _viaBle = false;
    });
    try {
      final host = _hostController.text.trim();
      final list = await widget.fetchList(host: host.isEmpty ? null : host);
      if (!mounted) return;
      setState(() {
        _list = list;
        _hostController.text = list.host;
        // Pre-select newest.
        if (list.shots.isNotEmpty) {
          _selected.add(list.shots.first.index);
        }
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
        _loading = false;
      });
    }
  }

  Future<void> _loadBle() async {
    setState(() {
      _loading = true;
      _error = null;
      _list = null;
      _selected.clear();
      _viaBle = true;
    });
    try {
      final list = await widget.fetchListBle();
      if (!mounted) return;
      setState(() {
        _list = list;
        if (list.shots.isNotEmpty) {
          _selected
            ..clear()
            ..addAll(list.shots.map((s) => s.index));
        }
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
        _loading = false;
      });
    }
  }

  Future<void> _importSelected() async {
    final list = _list;
    if (list == null || _selected.isEmpty) return;
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final ages = _selected.toList()..sort();
      final shots = <Shot>[];
      for (final age in ages) {
        final shot = _viaBle
            ? await widget.fetchShotBle(age: age)
            : await widget.fetchShot(
                host: list.host.startsWith('ble:') ? null : list.host,
                age: age,
              );
        shots.add(shot);
      }
      if (!mounted) return;
      Navigator.pop(context, shots);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
        _importing = false;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('import_scale_shot_dialog'),
      title: const Text('Import from scale'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('import_scale_host_field'),
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Scale IP or host',
                  hintText: '192.168.50.3',
                  helperText:
                      'Prefer the numeric IP from the scale web page / OLED. '
                      'half-decent.local often fails on phones.',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                onSubmitted: (_) => unawaited(_loadWifi()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('import_scale_wifi_refresh'),
                    onPressed: _loading || _importing
                        ? null
                        : () => unawaited(_loadWifi()),
                    icon: const Icon(Icons.wifi, size: 18),
                    label: const Text('Wi‑Fi'),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('import_scale_ble_refresh'),
                    onPressed: _loading || _importing
                        ? null
                        : () => unawaited(_loadBle()),
                    icon: const Icon(Icons.bluetooth, size: 18),
                    label: const Text('Bluetooth'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading || _importing)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _importing
                          ? 'Downloading selected shot(s)…'
                          : (_viaBle
                              ? 'Listing shots over Bluetooth…'
                              : 'Fetching /shots.json …'),
                    ),
                  ],
                )
              else if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
              else if (_list == null || _list!.shots.isEmpty)
                const Text(
                  'No shots stored on the scale yet.\n'
                  'Do a phone-free brew (Timer long-press → confirm), then retry.',
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _viaBle
                          ? 'Shots on scale (Bluetooth) — select to import:'
                          : 'Shots on ${_list!.host} — select to import:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final s in _list!.shots)
                      CheckboxListTile(
                        key: Key('import_scale_shot_option_${s.index}'),
                        dense: true,
                        value: _selected.contains(s.index),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(s.index);
                            } else {
                              _selected.remove(s.index);
                            }
                          });
                        },
                        title: Text(
                          s.index == 0
                              ? 'Newest${s.id != null ? ' · ${s.id}' : ''}'
                              : 'Shot −${s.index}${s.id != null ? ' · ${s.id}' : ''}',
                        ),
                        subtitle: Text(
                          [
                            if (s.startedAt != null) s.startedAt!,
                            if (s.samples != null) '${s.samples} samples',
                            if (s.yieldG != null && s.yieldG! > 0)
                              '${s.yieldG!.toStringAsFixed(1)} g',
                            if (s.bytes != null) '${s.bytes} B',
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('import_scale_shot_cancel'),
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_loading && !_importing)
          TextButton(
            key: const Key('import_scale_shot_retry'),
            onPressed: _viaBle ? _loadBle : _loadWifi,
            child: const Text('Retry'),
          ),
        if (!_loading &&
            !_importing &&
            _list != null &&
            _selected.isNotEmpty)
          FilledButton(
            key: const Key('import_scale_shot_import'),
            onPressed: () => unawaited(_importSelected()),
            child: Text(
              _selected.length == 1
                  ? 'Import'
                  : 'Import ${_selected.length}',
            ),
          ),
      ],
    );
  }
}
