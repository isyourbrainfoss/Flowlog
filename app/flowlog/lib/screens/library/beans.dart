import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Common retail bag sizes in grams (250g EU specialty, 500g half-kilo, 1kg).
const List<int> kBeanStockPresetsG = [200, 250, 500, 1000];

String _formatBeanDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// Interpolates roast slider color from light tan to dark brown.
Color _roastSliderColor(double sliderValue) {
  final t = sliderValue / (kBeanRoastLevels.length - 1);
  return Color.lerp(
    const Color(0xFFD4B896),
    const Color(0xFF2E1A0E),
    t.clamp(0.0, 1.0),
  )!;
}

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

    _database = await openFlowlogDatabase();
    _beanRepository = BeanRepository(_database!);
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
                      final allBeanModels = [
                        for (final item in beans) item.bean,
                      ];
                      return BeanCard(
                        entry: entry,
                        allBeans: allBeanModels,
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
    this.allBeans,
    required this.onTap,
    required this.onDelete,
    required this.onStockChanged,
  });

  final BeanWithShotCount entry;
  final List<Bean>? allBeans;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<double?> onStockChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bean = entry.bean;
    final title = formatBeanDisplayLabel(bean, allBeans: allBeans);
    final subtitle = [
      if (bean.brand != null &&
          bean.brand!.isNotEmpty &&
          !title.contains(bean.brand!))
        bean.brand,
      if (bean.origin != null && bean.origin!.isNotEmpty) bean.origin,
      if (bean.variety != null && bean.variety!.isNotEmpty) bean.variety,
      if (bean.process != null && bean.process!.isNotEmpty) bean.process,
      if (bean.roastLevel != null && bean.roastLevel!.isNotEmpty)
        bean.roastLevel,
      if (bean.roastDate != null && title == bean.name)
        'Roasted ${_formatBeanDate(bean.roastDate!)}',
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
                      title,
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
    barrierDismissible: false,
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
  late final TextEditingController _brandController;
  late final TextEditingController _originController;
  late final TextEditingController _varietyController;
  late final TextEditingController _stockController;
  late final TextEditingController _notesController;
  late double _roastSliderValue;
  DateTime? _roastDate;
  String? _selectedProcess;
  int? _selectedStockPreset;

  @override
  void initState() {
    super.initState();
    final bean = widget.bean;
    _nameController = TextEditingController(text: bean?.name ?? '');
    _brandController = TextEditingController(text: bean?.brand ?? '');
    _originController = TextEditingController(text: bean?.origin ?? '');
    _varietyController = TextEditingController(text: bean?.variety ?? '');
    _stockController = TextEditingController(
      text: bean?.stockG?.toString() ?? '',
    );
    _notesController = TextEditingController(text: bean?.notes ?? '');
    _roastSliderValue = _roastLevelToSlider(bean?.roastLevel);
    _roastDate = bean?.roastDate;
    _selectedProcess = bean?.process;
    _selectedStockPreset = _matchingStockPreset(bean?.stockG);
  }

  double _roastLevelToSlider(String? level) {
    if (level == null || level.isEmpty) {
      return 2;
    }
    final index = kBeanRoastLevels.indexWhere(
      (label) => label.toLowerCase() == level.toLowerCase(),
    );
    return (index >= 0 ? index : 2).toDouble();
  }

  String? _sliderToRoastLevel(double value) {
    final index = value.round().clamp(0, kBeanRoastLevels.length - 1);
    return kBeanRoastLevels[index];
  }

  int? _matchingStockPreset(double? stockG) {
    if (stockG == null) {
      return null;
    }
    final rounded = stockG.round();
    return kBeanStockPresetsG.contains(rounded) ? rounded : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _originController.dispose();
    _varietyController.dispose();
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

  bool get _isDirty {
    final bean = widget.bean;
    if (bean == null) {
      return _nameController.text.trim().isNotEmpty ||
          _brandController.text.trim().isNotEmpty ||
          _originController.text.trim().isNotEmpty ||
          _varietyController.text.trim().isNotEmpty ||
          _stockController.text.trim().isNotEmpty ||
          _notesController.text.trim().isNotEmpty ||
          _roastSliderValue != 2 ||
          _roastDate != null ||
          _selectedProcess != null;
    }

    final stock = _optionalStock(_stockController.text);
    return _nameController.text.trim() != bean.name ||
        _optionalText(_brandController.text) != bean.brand ||
        _optionalText(_originController.text) != bean.origin ||
        _optionalText(_varietyController.text) != bean.variety ||
        _sliderToRoastLevel(_roastSliderValue) != bean.roastLevel ||
        _roastDate != bean.roastDate ||
        _selectedProcess != bean.process ||
        stock != bean.stockG ||
        _optionalText(_notesController.text) != bean.notes;
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Discard unsaved bean changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _cancel() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }
    if (await _confirmDiscard() && mounted) {
      Navigator.pop(context);
    }
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
        brand: _optionalText(_brandController.text),
        origin: _optionalText(_originController.text),
        variety: _optionalText(_varietyController.text),
        roastLevel: _sliderToRoastLevel(_roastSliderValue),
        roastDate: _roastDate,
        process: _selectedProcess,
        stockG: stock,
        notes: _optionalText(_notesController.text),
      ),
    );
  }

  Future<void> _copyAiPrompt() async {
    await Clipboard.setData(ClipboardData(text: buildBeanAiPrompt()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        key: Key('bean_ai_prompt_copied_snackbar'),
        content: Text('AI prompt copied — paste it into your AI with a bag photo'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (!mounted) {
      return;
    }

    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('bean_ai_clipboard_empty_snackbar'),
          content: Text('Clipboard is empty — copy the AI code block first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final draft = parseBeanAiResponse(text);
      _applyBeanAiDraft(draft);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('bean_ai_imported_snackbar'),
          content: Text('Bean details imported from clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FormatException {
      final draft = await showBeanAiImportDialog(
        context,
        initialText: text,
      );
      if (!mounted || draft == null) {
        return;
      }
      _applyBeanAiDraft(draft);
    }
  }

  void _applyBeanAiDraft(BeanAiDraft draft) {
    setState(() {
      _nameController.text = draft.name;
      if (draft.brand != null) {
        _brandController.text = draft.brand!;
      }
      if (draft.origin != null) {
        _originController.text = draft.origin!;
      }
      if (draft.variety != null) {
        _varietyController.text = draft.variety!;
      }
      if (draft.notes != null) {
        _notesController.text = draft.notes!;
      }
      if (draft.roastLevel != null) {
        _roastSliderValue = _roastLevelToSlider(draft.roastLevel);
      }
      if (draft.roastDate != null) {
        _roastDate = draft.roastDate!.toLocal();
      }
      if (draft.process != null) {
        _selectedProcess = draft.process;
      }
      if (draft.stockG != null) {
        _stockController.text = draft.stockG!.truncateToDouble() == draft.stockG
            ? draft.stockG!.toStringAsFixed(0)
            : draft.stockG.toString();
        _selectedStockPreset = _matchingStockPreset(draft.stockG);
      }
    });
  }

  Future<void> _pickRoastDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _roastDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Roast date',
    );
    if (picked != null) {
      setState(() => _roastDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.bean != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (!_isDirty) {
          Navigator.pop(context);
          return;
        }
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AlertDialog(
      key: Key(isEditing ? 'bean_editor_edit' : 'bean_editor_add'),
      title: Text(isEditing ? 'Edit bean' : 'Add bean'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Auto-fill from bag photo',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Copy the prompt into any AI with a photo of the bag, '
                        'copy the AI\'s code block, then import from clipboard.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('bean_ai_copy_prompt'),
                              onPressed: _copyAiPrompt,
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              label: const Text('Copy prompt'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              key: const Key('bean_ai_import_clipboard'),
                              onPressed: _importFromClipboard,
                              icon: const Icon(Icons.content_paste_go_outlined,
                                  size: 18),
                              label: const Text('Import'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                key: const Key('bean_editor_brand'),
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'e.g. Onyx, Square Mile',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              TextFormField(
                controller: _originController,
                decoration: const InputDecoration(labelText: 'Origin'),
                textCapitalization: TextCapitalization.words,
              ),
              TextFormField(
                key: const Key('bean_editor_variety'),
                controller: _varietyController,
                decoration: const InputDecoration(
                  labelText: 'Variety',
                  hintText: 'e.g. Yellow Catuai',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              Text(
                'Process',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in kBeanProcessMethods)
                    FilterChip(
                      key: Key(
                        'bean_process_${method.toLowerCase().replaceAll(' ', '_')}',
                      ),
                      label: Text(method),
                      selected: _selectedProcess == method,
                      onSelected: (selected) {
                        setState(() {
                          _selectedProcess = selected ? method : null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Roast: ${_sliderToRoastLevel(_roastSliderValue)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _roastSliderColor(_roastSliderValue),
                  inactiveTrackColor: _roastSliderColor(_roastSliderValue)
                      .withValues(alpha: 0.28),
                  thumbColor: _roastSliderColor(_roastSliderValue),
                  overlayColor: _roastSliderColor(_roastSliderValue)
                      .withValues(alpha: 0.14),
                ),
                child: Slider(
                  key: const Key('bean_editor_roast_slider'),
                  value: _roastSliderValue,
                  min: 0,
                  max: (kBeanRoastLevels.length - 1).toDouble(),
                  divisions: kBeanRoastLevels.length - 1,
                  label: _sliderToRoastLevel(_roastSliderValue),
                  onChanged: (value) =>
                      setState(() => _roastSliderValue = value),
                ),
              ),
              ListTile(
                key: const Key('bean_editor_roast_date'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Roast date'),
                subtitle: Text(
                  _roastDate == null
                      ? 'Tap to pick a day'
                      : _formatBeanDate(_roastDate!),
                ),
                trailing: _roastDate == null
                    ? const Icon(Icons.calendar_today_outlined)
                    : IconButton(
                        tooltip: 'Clear roast date',
                        onPressed: () => setState(() => _roastDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                onTap: _pickRoastDate,
              ),
              const SizedBox(height: 4),
              Text(
                'Bag size (g)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a common size or type any weight below',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in kBeanStockPresetsG)
                    FilterChip(
                      key: Key('bean_stock_preset_$preset'),
                      label: Text('${preset}g'),
                      selected: _selectedStockPreset == preset,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedStockPreset = preset;
                            _stockController.text = preset.toString();
                          } else if (_selectedStockPreset == preset) {
                            _selectedStockPreset = null;
                            _stockController.clear();
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('bean_stock_custom_field'),
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Custom bag size (g)',
                  hintText: 'e.g. 340 or 454',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (value) {
                  final parsed = double.tryParse(value.trim());
                  setState(() {
                    _selectedStockPreset = _matchingStockPreset(parsed);
                  });
                },
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
          key: const Key('bean_editor_cancel'),
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('bean_editor_save'),
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    ),
    );
  }
}

/// Dialog for pasting an AI response and parsing bean fields.
Future<BeanAiDraft?> showBeanAiImportDialog(
  BuildContext context, {
  String initialText = '',
}) {
  return showDialog<BeanAiDraft>(
    context: context,
    builder: (dialogContext) => _BeanAiImportDialog(initialText: initialText),
  );
}

class _BeanAiImportDialog extends StatefulWidget {
  const _BeanAiImportDialog({this.initialText = ''});

  final String initialText;

  @override
  State<_BeanAiImportDialog> createState() => _BeanAiImportDialogState();
}

class _BeanAiImportDialogState extends State<_BeanAiImportDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = 'Clipboard is empty');
      return;
    }
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _import() {
    try {
      final draft = parseBeanAiResponse(_controller.text);
      Navigator.pop(context, draft);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('bean_ai_import_dialog'),
      title: const Text('Import from AI'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Paste the JSON code block your AI returned, or read it from '
                'the clipboard.',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('bean_ai_import_read_clipboard'),
                  onPressed: _readClipboard,
                  icon: const Icon(Icons.content_paste_outlined, size: 18),
                  label: const Text('Read clipboard'),
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('bean_ai_import_field'),
                controller: _controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{ "name": "...", ... }',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() => _error = null);
                  }
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('bean_ai_import_cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('bean_ai_import_apply'),
          onPressed: _import,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}