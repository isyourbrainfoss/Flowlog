import 'dart:convert';
import 'dart:io';

/// File-backed persistence for the current brew location label.
class BrewLocationStore {
  BrewLocationStore({String? settingsPath})
      : _settingsPath = settingsPath ?? _defaultSettingsPath;

  static String get _defaultSettingsPath =>
      '${Directory.systemTemp.path}/flowlog_brew_location.json';

  final String _settingsPath;

  Future<String?> load() async {
    final file = File(_settingsPath);
    if (!file.existsSync()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final location = decoded['currentLocation'];
      if (location is! String) {
        return null;
      }
      final trimmed = location.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String? location) async {
    final file = File(_settingsPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
        if (location != null && location.trim().isNotEmpty)
          'currentLocation': location.trim(),
      }),
    );
  }
}