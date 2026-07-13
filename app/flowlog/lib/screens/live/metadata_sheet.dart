import 'dart:async';

import 'package:flowlog/screens/live/brew_metadata_sliders.dart';
import 'package:flowlog/screens/more/equipment_screen.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog/settings/equipment_store.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';


/// Metadata fields captured after a shot, aligned with [Shot] properties.
@immutable
class ShotMetadata {
  const ShotMetadata({
    this.doseG,
    this.yieldG,
    this.grindSetting,
    this.beanId,
    this.waterTempC,
    this.notes,
    this.location,
    this.tasteScore,
    this.flavourTags = const [],
    this.flavourIntensities = const {},
    this.coffeejackRewindTurns,
    this.coffeejackPreinfusionTurns,
    this.grinder,
    this.showerScreen,
    this.basket,
    this.scale,
    this.brewer,
    this.lastModifiedAt,
  }) : assert(
          tasteScore == null || (tasteScore >= 0 && tasteScore <= 10),
          'tasteScore must be between 0 and 10',
        );

  final double? doseG;
  final double? yieldG;
  final double? grindSetting;
  final String? beanId;
  final double? waterTempC;
  final String? notes;
  final String? location;
  final int? tasteScore;
  final List<String> flavourTags;
  final Map<String, int> flavourIntensities;
  final int? coffeejackRewindTurns;
  final int? coffeejackPreinfusionTurns;
  final String? grinder;
  final String? showerScreen;
  final String? basket;
  final String? scale;
  final String? brewer;
  final DateTime? lastModifiedAt;

  factory ShotMetadata.fromShot(Shot shot) {
    return ShotMetadata(
      doseG: shot.doseG,
      yieldG: shot.yieldG,
      grindSetting: shot.grindSetting,
      beanId: shot.beanId,
      waterTempC: shot.waterTempC,
      notes: shot.notes,
      location: shot.location,
      tasteScore: shot.tasteScore,
      flavourTags: List<String>.from(shot.flavourTags),
      flavourIntensities: Map<String, int>.from(shot.flavourIntensities),
      coffeejackRewindTurns: shot.coffeejackRewindTurns,
      coffeejackPreinfusionTurns: shot.coffeejackPreinfusionTurns,
      grinder: shot.grinder,
      showerScreen: shot.showerScreen,
      basket: shot.basket,
      scale: shot.scale,
      brewer: shot.brewer,
      lastModifiedAt: shot.lastModifiedAt,
    );
  }

  Shot applyTo(Shot shot) {
    return shot.copyWith(
      doseG: doseG,
      yieldG: yieldG,
      grindSetting: grindSetting,
      beanId: beanId,
      waterTempC: waterTempC,
      notes: notes,
      location: location,
      tasteScore: tasteScore,
      flavourTags: flavourTags,
      flavourIntensities: flavourIntensities,
      coffeejackRewindTurns: coffeejackRewindTurns,
      coffeejackPreinfusionTurns: coffeejackPreinfusionTurns,
      grinder: grinder,
      showerScreen: showerScreen,
      basket: basket,
      scale: scale,
      brewer: brewer,
      lastModifiedAt: lastModifiedAt,
    );
  }

  ShotMetadata copyWith({
    double? doseG,
    double? yieldG,
    double? grindSetting,
    String? beanId,
    double? waterTempC,
    String? notes,
    String? location,
    int? tasteScore,
    List<String>? flavourTags,
    Map<String, int>? flavourIntensities,
    int? coffeejackRewindTurns,
    int? coffeejackPreinfusionTurns,
    String? grinder,
    String? showerScreen,
    String? basket,
    String? scale,
    String? brewer,
    DateTime? lastModifiedAt,
  }) {
    return ShotMetadata(
      doseG: doseG ?? this.doseG,
      yieldG: yieldG ?? this.yieldG,
      grindSetting: grindSetting ?? this.grindSetting,
      beanId: beanId ?? this.beanId,
      waterTempC: waterTempC ?? this.waterTempC,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      tasteScore: tasteScore ?? this.tasteScore,
      flavourTags: flavourTags ?? this.flavourTags,
      flavourIntensities: flavourIntensities ?? this.flavourIntensities,
      coffeejackRewindTurns:
          coffeejackRewindTurns ?? this.coffeejackRewindTurns,
      coffeejackPreinfusionTurns:
          coffeejackPreinfusionTurns ?? this.coffeejackPreinfusionTurns,
      grinder: grinder ?? this.grinder,
      showerScreen: showerScreen ?? this.showerScreen,
      basket: basket ?? this.basket,
      scale: scale ?? this.scale,
      brewer: brewer ?? this.brewer,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShotMetadata &&
            doseG == other.doseG &&
            yieldG == other.yieldG &&
            grindSetting == other.grindSetting &&
            beanId == other.beanId &&
            waterTempC == other.waterTempC &&
            notes == other.notes &&
            location == other.location &&
            tasteScore == other.tasteScore &&
            coffeejackRewindTurns == other.coffeejackRewindTurns &&
            coffeejackPreinfusionTurns == other.coffeejackPreinfusionTurns &&
            grinder == other.grinder &&
            showerScreen == other.showerScreen &&
            basket == other.basket &&
            scale == other.scale &&
            brewer == other.brewer &&
            lastModifiedAt == other.lastModifiedAt &&
            _listEquals(flavourTags, other.flavourTags) &&
            _mapEquals(flavourIntensities, other.flavourIntensities);
  }

  @override
  int get hashCode => Object.hash(
        doseG,
        yieldG,
        grindSetting,
        beanId,
        waterTempC,
        notes,
        location,
        tasteScore,
        coffeejackRewindTurns,
        coffeejackPreinfusionTurns,
        grinder,
        showerScreen,
        basket,
        scale,
        brewer,
        lastModifiedAt,
        Object.hashAll(flavourTags),
        Object.hashAll(flavourIntensities.entries),
      );
}

bool _mapEquals(Map<String, int> a, Map<String, int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Selectable flavour descriptors shown as chips in the metadata sheet.
const List<String> kFlavourTagOptions = [
  'bright',
  'bitter',
  'body',
  'chocolate',
  'nutty',
  'fruity',
  'acidic',
  'sweet',
  'floral',
  'caramel',
  'funky',
];

/// Preset chips plus any custom tags the user added this session.
List<String> flavourTagsForDisplay(Set<String> selected) {
  final custom = selected
      .where((tag) => !kFlavourTagOptions.contains(tag))
      .toList()
    ..sort();
  return [...kFlavourTagOptions, ...custom];
}

/// Shows a scrollable bottom sheet for entering shot metadata.
Future<ShotMetadata?> showMetadataSheet(
  BuildContext context, {
  ShotMetadata? initial,
  BeanRepository? beanRepository,
  String? activeBeanName,
}) {
  return showModalBottomSheet<ShotMetadata>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
      return SizedBox(
        height: sheetHeight,
        child: MetadataSheet(
          initial: initial,
          beanRepository: beanRepository,
          activeBeanName: activeBeanName ??
              ActiveBeanScope.maybeOf(context)?.name,
        ),
      );
    },
  );
}

/// Form for dose, yield, grind, bean, temp, notes, taste, and flavour tags.
class MetadataSheet extends StatefulWidget {
  const MetadataSheet({
    super.key,
    this.initial,
    this.beanRepository,
    this.activeBeanName,
  });

  final ShotMetadata? initial;
  final BeanRepository? beanRepository;
  final String? activeBeanName;

  @override
  State<MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  late final TextEditingController _yieldController;
  late final TextEditingController _beanController;
  late final TextEditingController _tempController;
  late final TextEditingController _notesController;
  late final TextEditingController _locationController;
  late final TextEditingController _grinderController;
  late final TextEditingController _showerScreenController;
  late final TextEditingController _basketController;
  late final TextEditingController _scaleController;
  late final TextEditingController _brewerController;
  late double _doseG;
  late double _grindSetting;
  late CoffeejackSettings _coffeejackSettings;
  late double _tasteScore;
  late Set<String> _selectedFlavourTags;

  double? _initialDose;
  double? _initialGrind;
  late Map<String, int> _flavourIntensities;
  final _customTagController = TextEditingController();
  final BrewDefaultsSettingsStore _brewDefaultsStore =
      BrewDefaultsSettingsStore();
  final CoffeejackSettingsStore _coffeejackSettingsStore =
      CoffeejackSettingsStore();
  final EquipmentStore _equipmentStore = EquipmentStore();
  List<Bean> _beans = const [];
  bool _beansReady = false;
  bool _defaultsReady = false;
  bool _equipmentReady = false;
  String? _selectedBeanId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _doseG = initial?.doseG ?? kDefaultBrewDoseG;
    _grindSetting = snapGrindSetting(
      initial?.grindSetting ?? kDefaultBrewGrindSetting,
    );
    _initialDose = _doseG;
    _initialGrind = _grindSetting;
    _coffeejackSettings = const CoffeejackSettings();
    _yieldController = TextEditingController(
      text: _formatDouble(initial?.yieldG),
    );
    _beanController = TextEditingController(
      text: _initialBeanLabel(initial?.beanId),
    );
    _tempController = TextEditingController(
      text: _formatDouble(initial?.waterTempC),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _locationController = TextEditingController(text: initial?.location ?? '');
    _grinderController = TextEditingController(text: initial?.grinder ?? '');
    _showerScreenController = TextEditingController(text: initial?.showerScreen ?? '');
    _basketController = TextEditingController(text: initial?.basket ?? '');
    _scaleController = TextEditingController(text: initial?.scale ?? '');
    _brewerController = TextEditingController(text: initial?.brewer ?? '');
    _tasteScore = (initial?.tasteScore ?? 5).toDouble();
    _selectedFlavourTags = Set<String>.from(initial?.flavourTags ?? const []);
    _flavourIntensities = Map<String, int>.from(
      initial?.flavourIntensities ?? const {},
    );
    _coffeejackSettings = CoffeejackSettings(
      rewindTurnsBeforeFill: initial?.coffeejackRewindTurns ??
          const CoffeejackSettings().rewindTurnsBeforeFill,
      slowPreinfusionTurns: initial?.coffeejackPreinfusionTurns ??
          const CoffeejackSettings().slowPreinfusionTurns,
    );
    unawaited(_loadDefaults());
    unawaited(_loadBeans());
    unawaited(_loadEquipment());
  }

  Future<void> _loadEquipment() async {
    await _equipmentStore.load();
    if (mounted) {
      setState(() => _equipmentReady = true);
      _maybeApplyDefaultPreset();
    }
  }

  void _maybeApplyDefaultPreset() {
    if (!_equipmentReady) return;
    final defaultId = _equipmentStore.settings.defaultPresetId;
    if (defaultId == null) return;

    // Only apply if no equipment has been set yet (from initial or manual)
    final hasEquipment = _grinderController.text.isNotEmpty ||
        _showerScreenController.text.isNotEmpty ||
        _basketController.text.isNotEmpty ||
        _scaleController.text.isNotEmpty ||
        _brewerController.text.isNotEmpty;
    if (hasEquipment) return;

    final preset = _equipmentStore.settings.presets.firstWhere(
      (p) => p.id == defaultId,
      orElse: () => const EquipmentPreset(id: '', name: '', selections: {}),
    );
    if (preset.id.isEmpty) return;

    preset.selections.forEach((cat, name) {
      switch (cat) {
        case 'grinder':
          _grinderController.text = name;
          break;
        case 'showerScreen':
          _showerScreenController.text = name;
          break;
        case 'basket':
          _basketController.text = name;
          break;
        case 'scale':
          _scaleController.text = name;
          break;
        case 'brewer':
          _brewerController.text = name;
          break;
      }
    });

    // Apply tied defaults from preset
    if (preset.defaultDoseG != null) {
      _doseG = preset.defaultDoseG!;
    }
    if (preset.defaultGrindSetting != null) {
      _grindSetting = snapGrindSetting(preset.defaultGrindSetting!);
    }
    if (preset.defaultRewindTurnsBeforeFill != null) {
      _coffeejackSettings = _coffeejackSettings.copyWith(
        rewindTurnsBeforeFill: preset.defaultRewindTurnsBeforeFill!,
      );
    }
    if (preset.defaultSlowPreinfusionTurns != null) {
      _coffeejackSettings = _coffeejackSettings.copyWith(
        slowPreinfusionTurns: preset.defaultSlowPreinfusionTurns!,
      );
    }

    setState(() {});
  }

  Future<void> _loadDefaults() async {
    BrewDefaultsSettings? brewDefaults;
    CoffeejackSettings? coffeejack;
    try {
      final results = await Future.wait([
        _brewDefaultsStore.load(),
        _coffeejackSettingsStore.load(),
      ]);
      if (!mounted) {
        return;
      }
      brewDefaults = results[0] as BrewDefaultsSettings;
      coffeejack = results[1] as CoffeejackSettings;
    } catch (_) {
      // Fall back to the values we already have (from init or const defaults).
      // Still allow the user to save.
    } finally {
      if (mounted) {
        final initial = widget.initial;
        setState(() {
          if (brewDefaults != null &&
              brewDefaults.useDefaultDose &&
              initial?.doseG == null) {
            _doseG = brewDefaults.defaultDoseG;
          }
          if (brewDefaults != null &&
              brewDefaults.useDefaultGrind &&
              initial?.grindSetting == null) {
            _grindSetting = snapGrindSetting(brewDefaults.defaultGrindSetting);
          }
          if (coffeejack != null && (brewDefaults?.useDefaultCoffeejack ?? true)) {
            _coffeejackSettings = CoffeejackSettings(
              rewindTurnsBeforeFill: initial?.coffeejackRewindTurns ??
                  coffeejack.rewindTurnsBeforeFill,
              slowPreinfusionTurns: initial?.coffeejackPreinfusionTurns ??
                  coffeejack.slowPreinfusionTurns,
            );
          }
          _defaultsReady = true;
        });
      }
    }
  }

  String _initialBeanLabel(String? beanId) {
    if (beanId != null && beanId.trim().isNotEmpty) {
      return beanId;
    }
    return widget.activeBeanName?.trim() ?? '';
  }

  Future<void> _loadBeans() async {
    final repository = widget.beanRepository;
    if (repository == null) {
      if (mounted) {
        setState(() => _beansReady = true);
      }
      return;
    }

    final beans = await repository.listBeansByRecentUse();
    if (!mounted) {
      return;
    }

    setState(() {
      _beans = beans;
      _beansReady = true;
      final beanId = widget.initial?.beanId;
      if (beanId != null) {
        Bean? match;
        for (final bean in beans) {
          if (bean.id == beanId) {
            match = bean;
            break;
          }
        }
        if (match != null) {
          _selectedBeanId = match.id;
          _beanController.text =
              formatBeanDisplayLabel(match, allBeans: beans);
        }
      } else if (_beanController.text.isEmpty &&
          widget.activeBeanName != null) {
        Bean? activeMatch;
        for (final bean in beans) {
          if (bean.name.toLowerCase() ==
              widget.activeBeanName!.trim().toLowerCase()) {
            activeMatch = bean;
            break;
          }
        }
        if (activeMatch != null) {
          _selectedBeanId = activeMatch.id;
          _beanController.text =
              formatBeanDisplayLabel(activeMatch, allBeans: beans);
        } else {
          _beanController.text = widget.activeBeanName!.trim();
        }
      }
    });
  }

  Future<void> _updateCoffeejack(CoffeejackSettings settings) async {
    setState(() => _coffeejackSettings = settings);
    await _coffeejackSettingsStore.save(settings);
  }

  @override
  void dispose() {
    _yieldController.dispose();
    _beanController.dispose();
    _tempController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    _grinderController.dispose();
    _showerScreenController.dispose();
    _basketController.dispose();
    _scaleController.dispose();
    _brewerController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _addCustomFlavourTag() {
    final tag = _normalizeFlavourTag(_customTagController.text);
    if (tag == null) {
      return;
    }

    setState(() {
      _selectedFlavourTags.add(tag);
      _flavourIntensities.putIfAbsent(tag, () => kDefaultFlavourIntensity);
      _customTagController.clear();
    });
  }

  String? _normalizeFlavourTag(String raw) {
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty) {
      return null;
    }
    return tag;
  }

  String _formatDouble(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  String? _parseString(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String?> _resolveBeanId() async {
    final repository = widget.beanRepository;
    final typed = _parseString(_beanController.text);
    if (typed == null) {
      return null;
    }

    if (repository == null) {
      return typed;
    }

    if (_selectedBeanId != null) {
      final selected = await repository.getBeanById(_selectedBeanId!);
      if (selected != null) {
        return selected.id;
      }
    }

    final byId = await repository.getBeanById(typed);
    if (byId != null) {
      return byId.id;
    }

    return (await repository.createBean(name: typed)).id;
  }

  Future<ShotMetadata> _buildMetadata() async {
    final activeBeanScope = ActiveBeanScope.maybeOf(context);
    final beanId = await _resolveBeanId();
    if (beanId != null && widget.beanRepository != null) {
      final bean = await widget.beanRepository!.getBeanById(beanId);
      if (bean != null) {
        activeBeanScope?.onActiveBeanChanged(
          bean.name,
          beanId: bean.id,
        );
      }
    }

    final flavourIntensities = normalizeFlavourIntensities(
      selectedTags: _selectedFlavourTags,
      intensities: _flavourIntensities,
    );

    return ShotMetadata(
      doseG: _doseG,
      yieldG: _parseDouble(_yieldController.text),
      grindSetting: snapGrindSetting(_grindSetting),
      beanId: beanId,
      waterTempC: _parseDouble(_tempController.text),
      notes: _parseString(_notesController.text),
      location: _parseString(_locationController.text),
      tasteScore: _tasteScore.round(),
      flavourTags: sortedFlavourTags(_selectedFlavourTags),
      flavourIntensities: flavourIntensities,
      coffeejackRewindTurns: _coffeejackSettings.rewindTurnsBeforeFill,
      coffeejackPreinfusionTurns: _coffeejackSettings.slowPreinfusionTurns,
      grinder: _parseString(_grinderController.text),
      showerScreen: _parseString(_showerScreenController.text),
      basket: _parseString(_basketController.text),
      scale: _parseString(_scaleController.text),
      brewer: _parseString(_brewerController.text),
      lastModifiedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _save() async {
    final metadata = await _buildMetadata();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(metadata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Shot metadata',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (!_defaultsReady)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      BrewMetadataSliders(
                        doseG: _doseG,
                        grindSetting: _grindSetting,
                        coffeejackSettings: _coffeejackSettings,
                        onDoseChanged: (value) => setState(() => _doseG = value),
                        onGrindChanged: (value) => setState(
                          () => _grindSetting = snapGrindSetting(value),
                        ),
                        onCoffeejackChanged: (settings) =>
                            unawaited(_updateCoffeejack(settings)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('metadata_yield'),
                            controller: _yieldController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Yield (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const Key('metadata_temp'),
                            controller: _tempController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Temp (°C)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 12),
              Autocomplete<Bean>(
                initialValue: TextEditingValue(text: _beanController.text),
                displayStringForOption: (bean) =>
                    formatBeanDisplayLabel(bean, allBeans: _beans),
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  if (query.isEmpty) {
                    return _beans;
                  }
                  return _beans.where((bean) {
                    final label = formatBeanDisplayLabel(
                      bean,
                      allBeans: _beans,
                    ).toLowerCase();
                    return label.contains(query) ||
                        bean.name.toLowerCase().contains(query);
                  });
                },
                onSelected: (bean) {
                  _selectedBeanId = bean.id;
                  _beanController.text =
                      formatBeanDisplayLabel(bean, allBeans: _beans);
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  if (controller.text != _beanController.text) {
                    controller.text = _beanController.text;
                  }
                  return TextField(
                    key: const Key('metadata_bean'),
                    controller: controller,
                    focusNode: focusNode,
                    enabled: _beansReady,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Bean',
                      border: OutlineInputBorder(),
                      helperText:
                          'Pick a saved bag (date shown when names repeat) '
                          'or type a new name to add another',
                    ),
                    onChanged: (value) {
                      _beanController.text = value;
                      _selectedBeanId = null;
                    },
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('metadata_location'),
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Home kitchen',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('metadata_notes'),
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Equipment', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  if (_equipmentReady && _equipmentStore.settings.presets.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Load preset',
                      onSelected: (presetId) {
                        final preset = _equipmentStore.settings.presets.firstWhere((p) => p.id == presetId);
                        preset.selections.forEach((cat, name) {
                          switch (cat) {
                            case 'grinder':
                              _grinderController.text = name;
                              break;
                            case 'showerScreen':
                              _showerScreenController.text = name;
                              break;
                            case 'basket':
                              _basketController.text = name;
                              break;
                            case 'scale':
                              _scaleController.text = name;
                              break;
                            case 'brewer':
                              _brewerController.text = name;
                              break;
                          }
                        });
                        // Apply preset-tied defaults if present (dose/grind)
                        if (preset.defaultDoseG != null && _doseG == _initialDose) {
                          _doseG = preset.defaultDoseG!;
                        }
                        if (preset.defaultGrindSetting != null && _grindSetting == _initialGrind) {
                          _grindSetting = snapGrindSetting(preset.defaultGrindSetting!);
                        }
                        if (preset.defaultRewindTurnsBeforeFill != null) {
                          _coffeejackSettings = _coffeejackSettings.copyWith(
                            rewindTurnsBeforeFill: preset.defaultRewindTurnsBeforeFill!,
                          );
                        }
                        if (preset.defaultSlowPreinfusionTurns != null) {
                          _coffeejackSettings = _coffeejackSettings.copyWith(
                            slowPreinfusionTurns: preset.defaultSlowPreinfusionTurns!,
                          );
                        }
                        setState(() {});
                      },
                      itemBuilder: (ctx) => _equipmentStore.settings.presets
                          .map((p) => PopupMenuItem(value: p.id, child: Text(p.name)))
                          .toList(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('Load preset', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const EquipmentScreen()),
                    ),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Manage', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _EquipmentAutocomplete(
                controller: _grinderController,
                label: 'Grinder',
                hint: 'e.g. Chestnut X',
                options: _equipmentReady ? _equipmentStore.itemsForCategory('grinder').map((e) => e.name).toList() : const [],
              ),
              const SizedBox(height: 4),
              _EquipmentAutocomplete(
                controller: _showerScreenController,
                label: 'Shower screen',
                hint: 'e.g. CoffeeJack v2, IKAPE v3',
                options: _equipmentReady ? _equipmentStore.itemsForCategory('showerScreen').map((e) => e.name).toList() : const [],
              ),
              const SizedBox(height: 4),
              _EquipmentAutocomplete(
                controller: _basketController,
                label: 'Basket',
                hint: 'e.g. CJ v2, IKAPE 54→32mm',
                options: _equipmentReady ? _equipmentStore.itemsForCategory('basket').map((e) => e.name).toList() : const [],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _EquipmentAutocomplete(
                      controller: _scaleController,
                      label: 'Scale',
                      hint: 'e.g. Acaia',
                      options: _equipmentReady ? _equipmentStore.itemsForCategory('scale').map((e) => e.name).toList() : const [],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _EquipmentAutocomplete(
                      controller: _brewerController,
                      label: 'Brewer',
                      hint: 'e.g. CoffeeJack v2',
                      options: _equipmentReady ? _equipmentStore.itemsForCategory('brewer').map((e) => e.name).toList() : const [],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Taste',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      key: const Key('metadata_taste_slider'),
                      value: _tasteScore,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: _tasteScore.round().toString(),
                      onChanged: (value) {
                        setState(() => _tasteScore = value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      key: const Key('metadata_taste_value'),
                      _tasteScore.round().toString(),
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Flavour tags',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                key: const Key('metadata_flavour_tags'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in flavourTagsForDisplay(_selectedFlavourTags))
                    FilterChip(
                      key: Key('metadata_flavour_$tag'),
                      label: Text(tag),
                      selected: _selectedFlavourTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFlavourTags.add(tag);
                            _flavourIntensities.putIfAbsent(
                              tag,
                              () => kDefaultFlavourIntensity,
                            );
                          } else {
                            _selectedFlavourTags.remove(tag);
                            _flavourIntensities.remove(tag);
                          }
                        });
                      },
                    ),
                ],
              ),
              if (_selectedFlavourTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Flavour intensity',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rate how much of each note you taste (1–10).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                for (final tag in sortedFlavourTags(_selectedFlavourTags))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FlavourIntensityRow(
                      tag: tag,
                      value: _flavourIntensities[tag] ?? kDefaultFlavourIntensity,
                      onChanged: (value) {
                        setState(() => _flavourIntensities[tag] = value);
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('metadata_custom_flavour_input'),
                      controller: _customTagController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'New tag',
                        hintText: 'e.g. funky, jammy',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addCustomFlavourTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: const Key('metadata_add_flavour_tag'),
                    onPressed: _addCustomFlavourTag,
                    child: const Text('Add'),
                  ),
                ],
              ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                key: const Key('metadata_save'),
                onPressed: _defaultsReady ? () => unawaited(_save()) : null,
                child: Text(_defaultsReady ? 'Save' : 'Loading defaults…'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlavourIntensityRow extends StatelessWidget {
  const _FlavourIntensityRow({
    required this.tag,
    required this.value,
    required this.onChanged,
  });

  final String tag;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            tag,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Slider(
            key: Key('metadata_flavour_intensity_$tag'),
            value: value.toDouble(),
            min: kMinFlavourIntensity.toDouble(),
            max: kMaxFlavourIntensity.toDouble(),
            divisions: kMaxFlavourIntensity - kMinFlavourIntensity,
            label: value.toString(),
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            key: Key('metadata_flavour_intensity_value_$tag'),
            value.toString(),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ),
      ],
    );
  }
}
/// Autocomplete for equipment that pulls suggestions from the user's list for the category,
/// while still allowing free-text custom entry.
class _EquipmentAutocomplete extends StatelessWidget {
  const _EquipmentAutocomplete({
    required this.controller,
    required this.label,
    required this.hint,
    required this.options,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.toLowerCase();
        if (q.isEmpty) return options;
        return options.where((o) => o.toLowerCase().contains(q));
      },
      onSelected: (selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        if (textController.text != controller.text) {
          textController.text = controller.text;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => controller.text = v,
        );
      },
    );
  }
}
