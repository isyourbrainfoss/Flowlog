import 'package:flowlog/settings/equipment_store.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../util/decimal_input.dart';

/// Simple management page for user's equipment inventory and presets.
class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final EquipmentStore _store = EquipmentStore();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _store.load();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _addItem() async {
    final result = await _showItemDialog();
    if (result != null) {
      await _store.addItem(result);
      setState(() {});
    }
  }

  Future<void> _editItem(EquipmentItem item) async {
    final result = await _showItemDialog(initial: item);
    if (result != null) {
      await _store.updateItem(result);
      setState(() {});
    }
  }

  Future<void> _deleteItem(EquipmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete equipment?'),
        content: Text('Remove "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.deleteItem(item.id);
      setState(() {});
    }
  }

  Future<EquipmentItem?> _showItemDialog({EquipmentItem? initial}) {
    return showDialog<EquipmentItem>(
      context: context,
      builder: (ctx) => _EquipmentItemDialog(initial: initial),
    );
  }

  Future<void> _addPreset() => _editPreset();

  Future<void> _editPreset([EquipmentPreset? existing]) async {
    final result = await showDialog<EquipmentPreset>(
      context: context,
      builder: (ctx) =>
          _EquipmentPresetDialog(existing: existing, store: _store),
    );

    if (result == null) {
      return;
    }
    if (existing == null) {
      await _store.addPreset(result);
    } else {
      await _store.updatePreset(result);
    }
    if (mounted) setState(() {});
  }

  Future<void> _deletePreset(EquipmentPreset p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('Remove "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.deletePreset(p.id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Equipment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final cat in kEquipmentCategories) ...[
            Text(
              kEquipmentCategoryLabels[cat] ?? cat,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            if (_store.itemsForCategory(cat).isEmpty)
              const Text('None yet', style: TextStyle(color: Colors.grey))
            else
              for (final item in _store.itemsForCategory(cat))
                ListTile(
                  title: Text(item.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editItem(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteItem(item),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
          ],
          const Divider(),
          Text('Presets', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (_store.settings.presets.isEmpty)
            const Text(
              'No presets yet. Create one to quickly load a full equipment setup.',
              style: TextStyle(color: Colors.grey),
            )
          else
            for (final p in _store.settings.presets)
              ListTile(
                leading: IconButton(
                  icon: Icon(
                    _store.settings.defaultPresetId == p.id
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  onPressed: () async {
                    final newDefault = _store.settings.defaultPresetId == p.id
                        ? null
                        : p.id;
                    await _store.setDefaultPreset(newDefault);
                    setState(() {});
                  },
                  tooltip: _store.settings.defaultPresetId == p.id
                      ? 'Clear default preset'
                      : 'Set as default preset',
                ),
                title: Text(p.name),
                subtitle: Text(
                  [
                    p.selections.entries
                        .map(
                          (e) =>
                              '${kEquipmentCategoryLabels[e.key] ?? e.key}: ${e.value}',
                        )
                        .join(', '),
                    if (p.defaultDoseG != null) 'dose: ${p.defaultDoseG}g',
                    if (p.defaultGrindSetting != null)
                      'grind: ${p.defaultGrindSetting}',
                    if (p.defaultRewindTurnsBeforeFill != null)
                      'rewind: ${p.defaultRewindTurnsBeforeFill}',
                    if (p.defaultSlowPreinfusionTurns != null)
                      'slow: ${p.defaultSlowPreinfusionTurns}',
                  ].join(' • '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('equipment_preset_edit_${p.id}'),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit preset',
                      onPressed: () => _editPreset(p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete preset',
                      onPressed: () => _deletePreset(p),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add equipment'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _addPreset,
                icon: const Icon(Icons.bookmark_add),
                label: const Text('New preset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Tip: In the metadata editor you can type custom names or pick from the list above. Presets let you quickly fill a whole setup (e.g. "CoffeeJack with original parts").',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _PresetCategoryPicker extends StatelessWidget {
  const _PresetCategoryPicker({
    required this.category,
    required this.items,
    required this.selectedName,
    required this.onChanged,
  });

  final String category;
  final List<EquipmentItem> items;
  final String? selectedName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = kEquipmentCategoryLabels[category] ?? category;
    if (items.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(
          'No items — add under $label first',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final value = items.any((i) => i.name == selectedName) ? selectedName! : '';

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('— none —')),
        for (final item in items)
          DropdownMenuItem<String>(value: item.name, child: Text(item.name)),
      ],
      onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
    );
  }
}

class _EquipmentItemDialog extends StatefulWidget {
  const _EquipmentItemDialog({this.initial});

  final EquipmentItem? initial;

  @override
  State<_EquipmentItemDialog> createState() => _EquipmentItemDialogState();
}

class _EquipmentItemDialogState extends State<_EquipmentItemDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late String _category =
      widget.initial?.category ?? kEquipmentCategories.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add equipment' : 'Edit equipment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: kEquipmentCategories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(kEquipmentCategoryLabels[c] ?? c),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _category = v ?? _category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Chestnut X',
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final id = widget.initial?.id ?? const Uuid().v4();
            Navigator.pop(
              context,
              EquipmentItem(id: id, name: name, category: _category),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EquipmentPresetDialog extends StatefulWidget {
  const _EquipmentPresetDialog({required this.store, this.existing});

  final EquipmentStore store;
  final EquipmentPreset? existing;

  @override
  State<_EquipmentPresetDialog> createState() => _EquipmentPresetDialogState();
}

class _EquipmentPresetDialogState extends State<_EquipmentPresetDialog> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _grind;
  late final TextEditingController _rewind;
  late final TextEditingController _slow;
  late final Map<String, String> _selections;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _dose = TextEditingController(
      text: existing?.defaultDoseG?.toString() ?? '',
    );
    _grind = TextEditingController(
      text: existing?.defaultGrindSetting?.toString() ?? '',
    );
    _rewind = TextEditingController(
      text: existing?.defaultRewindTurnsBeforeFill?.toString() ?? '',
    );
    _slow = TextEditingController(
      text: existing?.defaultSlowPreinfusionTurns?.toString() ?? '',
    );
    _selections = <String, String>{...?existing?.selections};
    for (final cat in kEquipmentCategories) {
      if (_selections.containsKey(cat)) continue;
      final items = widget.store.itemsForCategory(cat);
      if (items.isNotEmpty) _selections[cat] = items.first.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _grind.dispose();
    _rewind.dispose();
    _slow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'New equipment preset' : 'Edit preset',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          // Keep focused fields above the keyboard.
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('equipment_preset_name'),
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Preset name',
                  hintText: 'CoffeeJack original parts',
                ),
                textInputAction: TextInputAction.next,
                autofocus: widget.existing == null,
              ),
              const SizedBox(height: 16),
              Text('Equipment', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final cat in kEquipmentCategories) ...[
                _PresetCategoryPicker(
                  category: cat,
                  items: widget.store.itemsForCategory(cat),
                  selectedName: _selections[cat],
                  onChanged: (name) {
                    setState(() {
                      if (name == null || name.isEmpty) {
                        _selections.remove(cat);
                      } else {
                        _selections[cat] = name;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Text(
                'Optional defaults',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dose,
                decoration: const InputDecoration(
                  labelText: 'Default dose (g)',
                  hintText: '18.0',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _grind,
                decoration: const InputDecoration(
                  labelText: 'Default grind',
                  hintText: '4.2',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rewind,
                decoration: const InputDecoration(
                  labelText: 'Default rewind turns',
                  hintText: '5',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _slow,
                decoration: const InputDecoration(
                  labelText: 'Default slow preinfusion turns',
                  hintText: '5',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('equipment_preset_save'),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final dose = parseDecimal(_dose.text.trim());
            final grind = parseDecimal(_grind.text.trim());
            final rewind = int.tryParse(_rewind.text.trim());
            final slow = int.tryParse(_slow.text.trim());
            Navigator.pop(
              context,
              EquipmentPreset(
                id: widget.existing?.id ?? const Uuid().v4(),
                name: name,
                selections: Map<String, String>.from(_selections),
                defaultDoseG: dose,
                defaultGrindSetting: grind,
                defaultRewindTurnsBeforeFill: rewind,
                defaultSlowPreinfusionTurns: slow,
              ),
            );
          },
          child: Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
