import 'dart:async';

import 'package:flowlog/screens/live/brew_metadata_sliders.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

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
  late double _doseG;
  late double _grindSetting;
  late CoffeejackSettings _coffeejackSettings;
  late double _tasteScore;
  late Set<String> _selectedFlavourTags;
  late Map<String, int> _flavourIntensities;
  final _customTagController = TextEditingController();
  final BrewDefaultsSettingsStore _brewDefaultsStore =
      BrewDefaultsSettingsStore();
  final CoffeejackSettingsStore _coffeejackSettingsStore =
      CoffeejackSettingsStore();
  List<Bean> _beans = const [];
  bool _beansReady = false;
  bool _defaultsReady = false;
  String? _selectedBeanId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _doseG = initial?.doseG ?? kDefaultBrewDoseG;
    _grindSetting = snapGrindSetting(
      initial?.grindSetting ?? kDefaultBrewGrindSetting,
    );
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
    _tasteScore = (initial?.tasteScore ?? 5).toDouble();
    _selectedFlavourTags = Set<String>.from(initial?.flavourTags ?? const []);
    _flavourIntensities = Map<String, int>.from(
      initial?.flavourIntensities ?? const {},
    );
    unawaited(_loadDefaults());
    unawaited(_loadBeans());
  }

  Future<void> _loadDefaults() async {
    final results = await Future.wait([
      _brewDefaultsStore.load(),
      _coffeejackSettingsStore.load(),
    ]);
    if (!mounted) {
      return;
    }

    final brewDefaults = results[0] as BrewDefaultsSettings;
    final coffeejack = results[1] as CoffeejackSettings;
    final initial = widget.initial;

    setState(() {
      if (initial?.doseG == null) {
        _doseG = brewDefaults.defaultDoseG;
      }
      if (initial?.grindSetting == null) {
        _grindSetting = snapGrindSetting(brewDefaults.defaultGrindSetting);
      }
      _coffeejackSettings = CoffeejackSettings(
        rewindTurnsBeforeFill: initial?.coffeejackRewindTurns ??
            coffeejack.rewindTurnsBeforeFill,
        slowPreinfusionTurns: initial?.coffeejackPreinfusionTurns ??
            coffeejack.slowPreinfusionTurns,
      );
      _defaultsReady = true;
    });
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
    final beanId = await _resolveBeanId();
    if (beanId != null && widget.beanRepository != null) {
      final bean = await widget.beanRepository!.getBeanById(beanId);
      if (bean != null) {
        ActiveBeanScope.maybeOf(context)?.onActiveBeanChanged(
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
              const SizedBox(height: 20),
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
                onPressed: () => unawaited(_save()),
                child: const Text('Save'),
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