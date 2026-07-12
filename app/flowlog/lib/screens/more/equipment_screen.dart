import 'package:flowlog/settings/equipment_store.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.deleteItem(item.id);
      setState(() {});
    }
  }

  Future<EquipmentItem?> _showItemDialog({EquipmentItem? initial}) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    String category = initial?.category ?? kEquipmentCategories.first;

    return showDialog<EquipmentItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'Add equipment' : 'Edit equipment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              items: kEquipmentCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(kEquipmentCategoryLabels[c] ?? c)))
                  .toList(),
              onChanged: (v) => category = v ?? category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Chestnut X'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final id = initial?.id ?? const Uuid().v4();
              Navigator.pop(ctx, EquipmentItem(id: id, name: name, category: category));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPreset() async {
    // Simple preset creation: name + current selections from items (demo: pick one per category if available)
    final nameController = TextEditingController();
    final selections = <String, String>{};

    for (final cat in kEquipmentCategories) {
      final items = _store.itemsForCategory(cat);
      if (items.isNotEmpty) {
        selections[cat] = items.first.name; // default to first; user can edit later
      }
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New equipment preset'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Preset name', hintText: 'CoffeeJack original parts'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && selections.isNotEmpty) {
      final preset = EquipmentPreset(id: const Uuid().v4(), name: result, selections: selections);
      await _store.addPreset(preset);
      setState(() {});
    }
  }

  Future<void> _deletePreset(EquipmentPreset p) async {
    await _store.deletePreset(p.id);
    setState(() {});
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
            Text(kEquipmentCategoryLabels[cat] ?? cat, style: Theme.of(context).textTheme.titleSmall),
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
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _editItem(item)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteItem(item)),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
          ],
          const Divider(),
          Text('Presets', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (_store.settings.presets.isEmpty)
            const Text('No presets yet. Create one to quickly load a full equipment setup.', style: TextStyle(color: Colors.grey))
          else
            for (final p in _store.settings.presets)
              ListTile(
                title: Text(p.name),
                subtitle: Text(p.selections.entries.map((e) => '${kEquipmentCategoryLabels[e.key] ?? e.key}: ${e.value}').join(', ')),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _deletePreset(p)),
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
