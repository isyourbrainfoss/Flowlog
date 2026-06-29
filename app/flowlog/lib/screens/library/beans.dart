import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates a unique bean id for persistence.
typedef BeanIdGenerator = String Function();

/// Default id format: `bean-<utc-milliseconds>`.
String generateBeanId() {
  return 'bean-${DateTime.now().toUtc().millisecondsSinceEpoch}';
}

/// Bean inventory list with CRUD and linked shot counts.
class BeansScreen extends StatefulWidget {
  const BeansScreen({
    super.key,
    this.beanRepository,
    this.beanIdGenerator = generateBeanId,
  });

  /// Optional repository override for tests or dependency injection.
  final BeanRepository? beanRepository;

  /// Generates ids for newly created beans.
  final BeanIdGenerator beanIdGenerator;

  @override
  State<BeansScreen> createState() => _BeansScreenState();
}

class _BeansScreenState extends State<BeansScreen> {
  BeanRepository? _beanRepository;
  FlowlogDatabase? _database;
  bool _ownsRepository = false;
  late Future<List<BeanWithShotCount>> _beansFuture;

  @override
  void initState() {
    super.initState();
    _beansFuture = _loadBeans();
  }

  Future<BeanRepository> _ensureRepository() async {
    if (widget.beanRepository != null) {
      return widget.beanRepository!;
    }
    if (_beanRepository != null) {
      return _beanRepository!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _beanRepository = BeanRepository(_database!);
    _ownsRepository = true;
    return _beanRepository!;
  }

  Future<List<BeanWithShotCount>> _loadBeans() async {
    final repository = await _ensureRepository();
    return repository.listBeansWithShotCounts();
  }

  Future<void> _refresh() async {
    setState(() {
      _beansFuture = _loadBeans();
    });
    await _beansFuture;
  }

  Future<void> _openBeanEditor({Bean? bean}) async {
    final repository = await _ensureRepository();
    if (!mounted) {
      return;
    }
    final saved = await showBeanEditorDialog(
      context: context,
      bean: bean,
      beanIdGenerator: widget.beanIdGenerator,
    );

    if (!mounted || saved == null) {
      return;
    }

    if (bean == null) {
      await repository.upsertBean(saved);
    } else {
      await repository.updateBean(saved);
    }

    await _refresh();
  }

  Future<void> _deleteBean(Bean bean) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete bean'),
        content: Text('Delete "${bean.name}"? Linked shots keep their bean id.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final repository = await _ensureRepository();
    await repository.deleteBean(bean.id);
    await _refresh();
  }

  Future<void> _updateStock(Bean bean, double? stockG) async {
    final repository = await _ensureRepository();
    await repository.updateBean(bean.copyWith(stockG: stockG));
    await _refresh();
  }

  @override
  void dispose() {
    if (_ownsRepository) {
      _database?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BeanWithShotCount>>(
      future: _beansFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load beans: ${snapshot.error}'),
          );
        }

        final beans = snapshot.data ?? const <BeanWithShotCount>[];

        return Scaffold(
          body: beans.isEmpty
              ? const Center(child: Text('No beans yet'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: beans.length,
                    itemBuilder: (context, index) {
                      final entry = beans[index];
                      return BeanCard(
                        entry: entry,
                        onTap: () => _openBeanEditor(bean: entry.bean),
                        onDelete: () => _deleteBean(entry.bean),
                        onStockChanged: (stockG) =>
                            _updateStock(entry.bean, stockG),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            key: const Key('beans_add_fab'),
            onPressed: () => _openBeanEditor(),
            tooltip: 'Add bean',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// Summary card for a bean in the library list.
class BeanCard extends StatelessWidget {
  const BeanCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onStockChanged,
  });

  final BeanWithShotCount entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<double?> onStockChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bean = entry.bean;
    final subtitle = [
      if (bean.origin != null && bean.origin!.isNotEmpty) bean.origin,
      if (bean.roastLevel != null && bean.roastLevel!.isNotEmpty)
        bean.roastLevel,
    ].join(' · ');

    return Card(
      key: Key('bean_card_${bean.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bean.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    key: Key('bean_shot_count_${bean.id}'),
                    label: Text(
                      entry.shotCount == 1
                          ? '1 shot'
                          : '${entry.shotCount} shots',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    key: Key('bean_delete_${bean.id}'),
                    tooltip: 'Delete bean',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              BeanStockField(
                key: Key('bean_stock_${bean.id}'),
                stockG: bean.stockG,
                onSubmitted: onStockChanged,
              ),
              if (bean.notes != null && bean.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bean.notes!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline editable stock field in grams.
class BeanStockField extends StatefulWidget {
  const BeanStockField({
    super.key,
    required this.stockG,
    required this.onSubmitted,
  });

  final double? stockG;
  final ValueChanged<double?> onSubmitted;

  @override
  State<BeanStockField> createState() => _BeanStockFieldState();
}

class _BeanStockFieldState extends State<BeanStockField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatStock(widget.stockG));
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant BeanStockField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.stockG != widget.stockG) {
      _controller.text = _formatStock(widget.stockG);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _submit();
    }
  }

  String _formatStock(double? stockG) {
    if (stockG == null) {
      return '';
    }
    return stockG.toStringAsFixed(stockG.truncateToDouble() == stockG ? 0 : 1);
  }

  double? _parseStock(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  void _submit() {
    final parsed = _parseStock(_controller.text);
    if (parsed == widget.stockG) {
      return;
    }
    widget.onSubmitted(parsed);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: const InputDecoration(
        labelText: 'Stock (g)',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
    );
  }
}

/// Dialog for creating or editing a bean.
Future<Bean?> showBeanEditorDialog({
  required BuildContext context,
  Bean? bean,
  BeanIdGenerator beanIdGenerator = generateBeanId,
}) {
  return showDialog<Bean>(
    context: context,
    builder: (dialogContext) => _BeanEditorDialog(
      bean: bean,
      beanIdGenerator: beanIdGenerator,
    ),
  );
}

class _BeanEditorDialog extends StatefulWidget {
  const _BeanEditorDialog({
    required this.bean,
    required this.beanIdGenerator,
  });

  final Bean? bean;
  final BeanIdGenerator beanIdGenerator;

  @override
  State<_BeanEditorDialog> createState() => _BeanEditorDialogState();
}

class _BeanEditorDialogState extends State<_BeanEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _originController;
  late final TextEditingController _roastController;
  late final TextEditingController _stockController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final bean = widget.bean;
    _nameController = TextEditingController(text: bean?.name ?? '');
    _originController = TextEditingController(text: bean?.origin ?? '');
    _roastController = TextEditingController(text: bean?.roastLevel ?? '');
    _stockController = TextEditingController(
      text: bean?.stockG?.toString() ?? '',
    );
    _notesController = TextEditingController(text: bean?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _originController.dispose();
    _roastController.dispose();
    _stockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  double? _optionalStock(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final stock = _optionalStock(_stockController.text);
    if (_stockController.text.trim().isNotEmpty && stock == null) {
      return;
    }

    Navigator.pop(
      context,
      Bean(
        id: widget.bean?.id ?? widget.beanIdGenerator(),
        name: _nameController.text.trim(),
        origin: _optionalText(_originController.text),
        roastLevel: _optionalText(_roastController.text),
        stockG: stock,
        notes: _optionalText(_notesController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bean != null;

    return AlertDialog(
      key: Key(isEditing ? 'bean_editor_edit' : 'bean_editor_add'),
      title: Text(isEditing ? 'Edit bean' : 'Add bean'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _originController,
                decoration: const InputDecoration(labelText: 'Origin'),
                textCapitalization: TextCapitalization.words,
              ),
              TextFormField(
                controller: _roastController,
                decoration: const InputDecoration(labelText: 'Roast'),
              ),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock (g)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
              ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
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
          key: const Key('bean_editor_save'),
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}