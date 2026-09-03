import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Top-bar default bean, independent of the last shot's bean.
class DefaultBean {
  const DefaultBean({this.beanId, this.name});

  final String? beanId;
  final String? name;
}

/// File-backed persistence for the top-bar default bean.
class DefaultBeanStore {
  DefaultBeanStore({String? settingsPath})
      : _settingsPathOverride = settingsPath;

  final String? _settingsPathOverride;

  Future<String> _resolveSettingsPath() async {
    return _settingsPathOverride ??
        FlowlogStorage.shared.filePath('flowlog_default_bean.json');
  }

  Future<DefaultBean> load() async {
    final file = File(await _resolveSettingsPath());
    if (!file.existsSync()) {
      return const DefaultBean();
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const DefaultBean();
      }
      return DefaultBean(
        beanId: _nonEmptyString(decoded['beanId']),
        name: _nonEmptyString(decoded['name']),
      );
    } catch (_) {
      return const DefaultBean();
    }
  }

  Future<void> save(DefaultBean bean) async {
    final file = File(await _resolveSettingsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        'beanId': bean.beanId,
        'name': bean.name,
      }),
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
