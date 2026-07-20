import 'dart:convert';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';

/// Categories for user equipment.
const List<String> kEquipmentCategories = [
  'grinder',
  'showerScreen',
  'basket',
  'scale',
  'brewer',
];

/// Human labels for categories.
const Map<String, String> kEquipmentCategoryLabels = {
  'grinder': 'Grinder',
  'showerScreen': 'Shower screen',
  'basket': 'Basket',
  'scale': 'Scale',
  'brewer': 'Brewer / Machine',
};

/// A piece of user equipment.
class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.category,
  });

  final String id;
  final String name;
  final String category; // one of kEquipmentCategories

  factory EquipmentItem.fromJson(Map<String, dynamic> json) {
    return EquipmentItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
      };

  EquipmentItem copyWith({String? name, String? category}) {
    return EquipmentItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
    );
  }
}

/// Named preset of equipment selections (e.g. "CoffeeJack original parts").
class EquipmentPreset {
  const EquipmentPreset({
    required this.id,
    required this.name,
    required this.selections, // category -> equipment name
    this.defaultDoseG,
    this.defaultGrindSetting,
    this.defaultRewindTurnsBeforeFill,
    this.defaultSlowPreinfusionTurns,
  });

  final String id;
  final String name;
  final Map<String, String> selections;

  /// Optional defaults tied to this equipment setup.
  final double? defaultDoseG;
  final double? defaultGrindSetting;
  final int? defaultRewindTurnsBeforeFill;
  final int? defaultSlowPreinfusionTurns;

  factory EquipmentPreset.fromJson(Map<String, dynamic> json) {
    return EquipmentPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      selections: Map<String, String>.from(json['selections'] as Map),
      defaultDoseG: (json['defaultDoseG'] as num?)?.toDouble(),
      defaultGrindSetting: (json['defaultGrindSetting'] as num?)?.toDouble(),
      defaultRewindTurnsBeforeFill: (json['defaultRewindTurnsBeforeFill'] as num?)?.toInt(),
      defaultSlowPreinfusionTurns: (json['defaultSlowPreinfusionTurns'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'selections': selections,
        if (defaultDoseG != null) 'defaultDoseG': defaultDoseG,
        if (defaultGrindSetting != null) 'defaultGrindSetting': defaultGrindSetting,
        if (defaultRewindTurnsBeforeFill != null) 'defaultRewindTurnsBeforeFill': defaultRewindTurnsBeforeFill,
        if (defaultSlowPreinfusionTurns != null) 'defaultSlowPreinfusionTurns': defaultSlowPreinfusionTurns,
      };

  EquipmentPreset copyWith({
    String? name,
    Map<String, String>? selections,
    double? defaultDoseG,
    double? defaultGrindSetting,
    int? defaultRewindTurnsBeforeFill,
    int? defaultSlowPreinfusionTurns,
  }) {
    return EquipmentPreset(
      id: id,
      name: name ?? this.name,
      selections: selections ?? this.selections,
      defaultDoseG: defaultDoseG ?? this.defaultDoseG,
      defaultGrindSetting: defaultGrindSetting ?? this.defaultGrindSetting,
      defaultRewindTurnsBeforeFill: defaultRewindTurnsBeforeFill ?? this.defaultRewindTurnsBeforeFill,
      defaultSlowPreinfusionTurns: defaultSlowPreinfusionTurns ?? this.defaultSlowPreinfusionTurns,
    );
  }
}

/// User's equipment inventory and presets.
class EquipmentSettings {
  const EquipmentSettings({
    this.items = const [],
    this.presets = const [],
    this.defaultPresetId,
  });

  final List<EquipmentItem> items;
  final List<EquipmentPreset> presets;
  final String? defaultPresetId;

  EquipmentSettings copyWith({
    List<EquipmentItem>? items,
    List<EquipmentPreset>? presets,
    String? defaultPresetId,
  }) {
    return EquipmentSettings(
      items: items ?? this.items,
      presets: presets ?? this.presets,
      defaultPresetId: defaultPresetId ?? this.defaultPresetId,
    );
  }
}

/// Persisted user equipment (items + presets).
class EquipmentStore {
  EquipmentStore({this._path});

  final String? _path;
  EquipmentSettings _settings = const EquipmentSettings();

  Future<String> _effectivePath() async {
    if (_path != null) return _path;
    return FlowlogStorage.shared.equipmentPath();
  }

  EquipmentSettings get settings => _settings;

  Future<void> load() async {
    try {
      final path = await _effectivePath();
      final file = File(path);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final items = (json['items'] as List<dynamic>? ?? [])
            .map((e) => EquipmentItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final presets = (json['presets'] as List<dynamic>? ?? [])
            .map((e) => EquipmentPreset.fromJson(e as Map<String, dynamic>))
            .toList();
        _settings = EquipmentSettings(
          items: items,
          presets: presets,
          defaultPresetId: json['defaultPresetId'] as String?,
        );
      }
    } catch (_) {
      // ignore corrupt file
      _settings = const EquipmentSettings();
    }
  }

  Future<void> save(EquipmentSettings settings) async {
    _settings = settings;
    final path = await _effectivePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'items': settings.items.map((e) => e.toJson()).toList(),
      'presets': settings.presets.map((e) => e.toJson()).toList(),
      if (settings.defaultPresetId != null) 'defaultPresetId': settings.defaultPresetId,
    }));
  }

  Future<void> addItem(EquipmentItem item) async {
    final items = List<EquipmentItem>.from(_settings.items)..add(item);
    await save(_settings.copyWith(items: items));
  }

  Future<void> updateItem(EquipmentItem item) async {
    final items = _settings.items.map((e) => e.id == item.id ? item : e).toList();
    await save(_settings.copyWith(items: items));
  }

  Future<void> deleteItem(String id) async {
    final items = _settings.items.where((e) => e.id != id).toList();
    await save(_settings.copyWith(items: items));
  }

  Future<void> addPreset(EquipmentPreset preset) async {
    final presets = List<EquipmentPreset>.from(_settings.presets)..add(preset);
    await save(_settings.copyWith(presets: presets));
  }

  Future<void> updatePreset(EquipmentPreset preset) async {
    final presets = _settings.presets
        .map((p) => p.id == preset.id ? preset : p)
        .toList();
    await save(_settings.copyWith(presets: presets));
  }

  Future<void> deletePreset(String id) async {
    final presets = _settings.presets.where((p) => p.id != id).toList();
    String? newDefault = _settings.defaultPresetId;
    if (newDefault == id) newDefault = null;
    await save(_settings.copyWith(presets: presets, defaultPresetId: newDefault));
  }

  Future<void> setDefaultPreset(String? presetId) async {
    if (presetId != null && !_settings.presets.any((p) => p.id == presetId)) {
      return; // invalid
    }
    await save(_settings.copyWith(defaultPresetId: presetId));
  }

  /// Get items for a category.
  List<EquipmentItem> itemsForCategory(String category) {
    return _settings.items.where((i) => i.category == category).toList();
  }

  /// Apply a preset to category selections (map category -> name).
  Map<String, String> applyPreset(String presetId) {
    final preset = _settings.presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => const EquipmentPreset(id: '', name: '', selections: {}),
    );
    return Map<String, String>.from(preset.selections);
  }
}
