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
    this.tasteScore,
    this.flavourTags = const [],
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
  final int? tasteScore;
  final List<String> flavourTags;

  factory ShotMetadata.fromShot(Shot shot) {
    return ShotMetadata(
      doseG: shot.doseG,
      yieldG: shot.yieldG,
      grindSetting: shot.grindSetting,
      beanId: shot.beanId,
      waterTempC: shot.waterTempC,
      notes: shot.notes,
      tasteScore: shot.tasteScore,
      flavourTags: List<String>.from(shot.flavourTags),
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
      tasteScore: tasteScore,
      flavourTags: flavourTags,
    );
  }

  ShotMetadata copyWith({
    double? doseG,
    double? yieldG,
    double? grindSetting,
    String? beanId,
    double? waterTempC,
    String? notes,
    int? tasteScore,
    List<String>? flavourTags,
  }) {
    return ShotMetadata(
      doseG: doseG ?? this.doseG,
      yieldG: yieldG ?? this.yieldG,
      grindSetting: grindSetting ?? this.grindSetting,
      beanId: beanId ?? this.beanId,
      waterTempC: waterTempC ?? this.waterTempC,
      notes: notes ?? this.notes,
      tasteScore: tasteScore ?? this.tasteScore,
      flavourTags: flavourTags ?? this.flavourTags,
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
            tasteScore == other.tasteScore &&
            _listEquals(flavourTags, other.flavourTags);
  }

  @override
  int get hashCode => Object.hash(
        doseG,
        yieldG,
        grindSetting,
        beanId,
        waterTempC,
        notes,
        tasteScore,
        Object.hashAll(flavourTags),
      );
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
];

/// Shows a scrollable bottom sheet for entering shot metadata.
Future<ShotMetadata?> showMetadataSheet(
  BuildContext context, {
  ShotMetadata? initial,
}) {
  return showModalBottomSheet<ShotMetadata>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
      return SizedBox(
        height: sheetHeight,
        child: MetadataSheet(initial: initial),
      );
    },
  );
}

/// Form for dose, yield, grind, bean, temp, notes, taste, and flavour tags.
class MetadataSheet extends StatefulWidget {
  const MetadataSheet({
    super.key,
    this.initial,
  });

  final ShotMetadata? initial;

  @override
  State<MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<MetadataSheet> {
  late final TextEditingController _doseController;
  late final TextEditingController _yieldController;
  late final TextEditingController _grindController;
  late final TextEditingController _beanController;
  late final TextEditingController _tempController;
  late final TextEditingController _notesController;
  late double _tasteScore;
  late Set<String> _selectedFlavourTags;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _doseController = TextEditingController(
      text: _formatDouble(initial?.doseG),
    );
    _yieldController = TextEditingController(
      text: _formatDouble(initial?.yieldG),
    );
    _grindController = TextEditingController(
      text: _formatDouble(initial?.grindSetting),
    );
    _beanController = TextEditingController(text: initial?.beanId ?? '');
    _tempController = TextEditingController(
      text: _formatDouble(initial?.waterTempC),
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _tasteScore = (initial?.tasteScore ?? 5).toDouble();
    _selectedFlavourTags = Set<String>.from(initial?.flavourTags ?? const []);
  }

  @override
  void dispose() {
    _doseController.dispose();
    _yieldController.dispose();
    _grindController.dispose();
    _beanController.dispose();
    _tempController.dispose();
    _notesController.dispose();
    super.dispose();
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

  ShotMetadata _buildMetadata() {
    return ShotMetadata(
      doseG: _parseDouble(_doseController.text),
      yieldG: _parseDouble(_yieldController.text),
      grindSetting: _parseDouble(_grindController.text),
      beanId: _parseString(_beanController.text),
      waterTempC: _parseDouble(_tempController.text),
      notes: _parseString(_notesController.text),
      tasteScore: _tasteScore.round(),
      flavourTags: _selectedFlavourTags.toList()..sort(),
    );
  }

  void _save() {
    Navigator.of(context).pop(_buildMetadata());
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('metadata_dose'),
                      controller: _doseController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Dose (g)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('metadata_grind'),
                      controller: _grindController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Grind',
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
              TextField(
                key: const Key('metadata_bean'),
                controller: _beanController,
                decoration: const InputDecoration(
                  labelText: 'Bean',
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
                  for (final tag in kFlavourTagOptions)
                    FilterChip(
                      key: Key('metadata_flavour_$tag'),
                      label: Text(tag),
                      selected: _selectedFlavourTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFlavourTags.add(tag);
                          } else {
                            _selectedFlavourTags.remove(tag);
                          }
                        });
                      },
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
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}