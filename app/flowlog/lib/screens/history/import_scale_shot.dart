import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flowlog/settings/scale_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Default hosts tried when importing a phone-free brew from the DIY scale.
const kDefaultScaleShotHosts = <String>[
  'half-decent.local',
  'half-decent',
];

/// Fetches Flowlog-compatible shot JSON from the scale HTTP endpoint.
Future<Shot> fetchShotFromScale({
  List<String> hosts = kDefaultScaleShotHosts,
  String? preferredHost,
  http.Client? client,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final httpClient = client ?? http.Client();
  final ownsClient = client == null;
  Object? lastError;

  final tried = <String>[];
  final ordered = <String>[
    if (preferredHost != null && preferredHost.trim().isNotEmpty)
      preferredHost.trim(),
    ...hosts,
  ];

  try {
    for (final raw in ordered) {
      final host = raw.trim();
      if (host.isEmpty || tried.contains(host)) {
        continue;
      }
      tried.add(host);
      final uri = Uri.parse('http://$host/shot.json');
      try {
        final response = await httpClient.get(uri).timeout(timeout);
        if (response.statusCode == 404) {
          lastError = StateError('No shot saved on scale yet ($host)');
          continue;
        }
        if (response.statusCode != 200) {
          lastError = StateError(
            'Scale at $host returned HTTP ${response.statusCode}',
          );
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('shot.json is not an object');
        }
        // Remember working host for next import (mDNS often fails on phones).
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
    throw StateError(
      'Could not reach the scale.\n'
      'Tried: ${tried.join(', ')}\n'
      'Tip: open http://<scale-ip>/ on your phone (Wi‑Fi status on the scale OLED) '
      'and enter that IP below.\n'
      'Last error: $lastError',
    );
  } finally {
    if (ownsClient) {
      httpClient.close();
    }
  }
}

/// Dialog to import the last phone-free shot recorded on the Flowlog DIY scale.
Future<Shot?> showImportScaleShotDialog(
  BuildContext context, {
  Future<Shot> Function({String? host})? fetchShot,
}) {
  return showDialog<Shot>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ImportScaleShotDialog(
      fetchShot: fetchShot ??
          ({String? host}) => fetchShotFromScale(preferredHost: host),
    ),
  );
}

class _ImportScaleShotDialog extends StatefulWidget {
  const _ImportScaleShotDialog({required this.fetchShot});

  final Future<Shot> Function({String? host}) fetchShot;

  @override
  State<_ImportScaleShotDialog> createState() => _ImportScaleShotDialogState();
}

class _ImportScaleShotDialogState extends State<_ImportScaleShotDialog> {
  bool _loading = true;
  String? _error;
  Shot? _shot;
  late final TextEditingController _hostController;

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
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _shot = null;
    });
    try {
      final host = _hostController.text.trim();
      final shot = await widget.fetchShot(host: host.isEmpty ? null : host);
      if (!mounted) return;
      setState(() {
        _shot = shot;
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
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('import_scale_host_field'),
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Scale host or IP',
                hintText: '192.168.50.3 or half-decent.local',
                helperText: 'mDNS often fails — use the IP from the scale Wi‑Fi page',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => unawaited(_load()),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching /shot.json …'),
                ],
              )
            else if (_error != null)
              Text(_error!)
            else if (_shot == null)
              const Text('No shot found.')
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Found shot with ${_shot!.samples.length} samples.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yield: ${_shot!.yieldG?.toStringAsFixed(1) ?? '—'} g'
                    '\nStarted: ${_formatTime(_shot!.startedAt)}'
                    '\nNotes: ${_shot!.notes ?? '—'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('import_scale_shot_cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (!_loading)
          TextButton(
            key: const Key('import_scale_shot_retry'),
            onPressed: _load,
            child: const Text('Retry'),
          ),
        if (!_loading && _shot != null)
          FilledButton(
            key: const Key('import_scale_shot_import'),
            onPressed: () => Navigator.pop(context, _shot),
            child: const Text('Import'),
          ),
      ],
    );
  }

  static String _formatTime(DateTime t) {
    final local = t.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
