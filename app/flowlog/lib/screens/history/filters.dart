import 'dart:async';

import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Filter controls for the history shot list.
///
/// Text fields debounce [onChanged] so typing does not reload the list (and
/// dismiss the soft keyboard) on every keystroke.
class HistoryFiltersPanel extends StatefulWidget {
  const HistoryFiltersPanel({
    super.key,
    required this.filters,
    required this.onChanged,
    this.tags = const [],
    this.beanSuggestions = const [],
  });

  final ShotListFilters filters;
  final ValueChanged<ShotListFilters> onChanged;
  final List<Tag> tags;

  /// Bean names (and ids) offered by autocomplete for the bean filter.
  final List<Bean> beanSuggestions;

  @override
  State<HistoryFiltersPanel> createState() => _HistoryFiltersPanelState();
}

class _HistoryFiltersPanelState extends State<HistoryFiltersPanel> {
  static const _textDebounce = Duration(milliseconds: 400);

  late final TextEditingController _beanController;
  late final TextEditingController _minPeakController;
  late final TextEditingController _maxPeakController;
  late final TextEditingController _minDurationController;
  late final TextEditingController _maxDurationController;
  late final TextEditingController _minGrindController;
  late final TextEditingController _maxGrindController;
  late final FocusNode _beanFocusNode;

  Timer? _debounce;
  bool _moreExpanded = false;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _beanController = TextEditingController(text: widget.filters.beanQuery);
    _minPeakController = TextEditingController(
      text: _formatNumber(widget.filters.minPeakPressureBar),
    );
    _maxPeakController = TextEditingController(
      text: _formatNumber(widget.filters.maxPeakPressureBar),
    );
    _minDurationController = TextEditingController(
      text: _formatDurationSec(widget.filters.minDurationMs),
    );
    _maxDurationController = TextEditingController(
      text: _formatDurationSec(widget.filters.maxDurationMs),
    );
    _minGrindController = TextEditingController(
      text: _formatNumber(widget.filters.minGrindSetting),
    );
    _maxGrindController = TextEditingController(
      text: _formatNumber(widget.filters.maxGrindSetting),
    );
    _beanFocusNode = FocusNode();
    _moreExpanded =
        widget.filters.minDurationMs != null ||
        widget.filters.maxDurationMs != null ||
        widget.filters.minGrindSetting != null ||
        widget.filters.maxGrindSetting != null ||
        widget.filters.maxPeakPressureBar != null;
    _filtersExpanded = _hiddenFiltersAreActive(widget.filters);
  }

  @override
  void didUpdateWidget(covariant HistoryFiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External clear / reset only — never fight the keyboard mid-type.
    if (oldWidget.filters.isActive && !widget.filters.isActive) {
      if (_beanController.text.isNotEmpty) {
        _beanController.clear();
      }
      if (_minPeakController.text.isNotEmpty) {
        _minPeakController.clear();
      }
      if (_maxPeakController.text.isNotEmpty) {
        _maxPeakController.clear();
      }
      if (_minDurationController.text.isNotEmpty) {
        _minDurationController.clear();
      }
      if (_maxDurationController.text.isNotEmpty) {
        _maxDurationController.clear();
      }
      if (_minGrindController.text.isNotEmpty) {
        _minGrindController.clear();
      }
      if (_maxGrindController.text.isNotEmpty) {
        _maxGrindController.clear();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabVisible = TickerMode.valuesOf(context).enabled;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if ((!tabVisible || !routeCurrent) && _beanFocusNode.hasFocus) {
      _beanFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _beanController.dispose();
    _minPeakController.dispose();
    _maxPeakController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    _minGrindController.dispose();
    _maxGrindController.dispose();
    _beanFocusNode.dispose();
    super.dispose();
  }

  void _emit(ShotListFilters filters, {bool immediate = false}) {
    if (immediate) {
      _debounce?.cancel();
      widget.onChanged(filters);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(_textDebounce, () {
      if (mounted) {
        widget.onChanged(filters);
      }
    });
  }

  void _emitBeanQuery(String value) {
    _emit(widget.filters.copyWith(beanQuery: value));
  }

  List<Bean> _matchingBeans(String query) {
    if (query.trim().isEmpty) {
      return widget.beanSuggestions.take(8).toList(growable: false);
    }
    return widget.beanSuggestions
        .where((bean) => beanMatchesQuery(bean, query))
        .take(8)
        .toList(growable: false);
  }

  void _clearBeanQuery() {
    _beanController.clear();
    _emit(widget.filters.copyWith(beanQuery: ''), immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < ShellBreakpoints.sidebar;
    final showAdvanced = !compact || _filtersExpanded;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Text('Filters', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
            ],
            Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      _beanFocusNode.unfocus();
                      return null;
                    },
                  ),
                },
                child: RawAutocomplete<Bean>(
                  key: const Key('history_filter_bean_autocomplete'),
                  textEditingController: _beanController,
                  focusNode: _beanFocusNode,
                  displayStringForOption: (bean) => formatBeanDisplayLabel(
                    bean,
                    allBeans: widget.beanSuggestions,
                  ),
                  optionsBuilder: (textEditingValue) {
                    return _matchingBeans(textEditingValue.text);
                  },
                  onSelected: (bean) {
                    _beanController.text = bean.name;
                    _emitBeanQuery(bean.name);
                    // Apply immediately when picking a suggestion.
                    _emit(
                      widget.filters.copyWith(beanQuery: bean.name),
                      immediate: true,
                    );
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) {
                            return TextField(
                              key: const Key('history_filter_bean'),
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Bean, roaster or origin',
                                hintText: 'e.g. KAFFA or Oslo',
                                isDense: true,
                                prefixIcon: const Icon(Icons.search, size: 20),
                                suffixIcon: controller.text.isEmpty
                                    ? null
                                    : IconButton(
                                        key: const Key(
                                          'history_filter_bean_clear',
                                        ),
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: _clearBeanQuery,
                                      ),
                              ),
                              textInputAction: TextInputAction.search,
                              onTapOutside: (_) => focusNode.unfocus(),
                              onChanged: _emitBeanQuery,
                              onSubmitted: (value) {
                                _emit(
                                  widget.filters.copyWith(beanQuery: value),
                                  immediate: true,
                                );
                                onFieldSubmitted();
                              },
                            );
                          },
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 220,
                            maxWidth: 360,
                          ),
                          child: ListView.builder(
                            key: const Key('history_filter_bean_options'),
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final bean = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(
                                  formatBeanDisplayLabel(
                                    bean,
                                    allBeans: widget.beanSuggestions,
                                  ),
                                ),
                                subtitle: () {
                                  final parts = [
                                    if (bean.brand != null &&
                                        bean.brand!.trim().isNotEmpty)
                                      bean.brand!.trim(),
                                    if (bean.origin != null &&
                                        bean.origin!.trim().isNotEmpty)
                                      bean.origin!.trim(),
                                  ];
                                  if (parts.isEmpty) {
                                    return null;
                                  }
                                  return Text(
                                    parts.join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }(),
                                onTap: () => onSelected(bean),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (compact) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    key: const Key('history_filter_toggle'),
                    onPressed: () =>
                        setState(() => _filtersExpanded = !_filtersExpanded),
                    icon: Icon(
                      _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: const Text('Filters'),
                  ),
                  const Spacer(),
                  if (widget.filters.isActive)
                    TextButton(
                      key: const Key('history_filter_clear'),
                      onPressed: _clearAllFilters,
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ] else
              const SizedBox(height: 8),
            if (showAdvanced) ..._advancedFilterControls(theme),
            if (!compact && widget.filters.isActive) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('history_filter_clear'),
                  onPressed: _clearAllFilters,
                  child: const Text('Clear filters'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _advancedFilterControls(ThemeData theme) {
    return [
      Row(
        children: [
          Expanded(
            child: _DateFilterButton(
              key: const Key('history_filter_date_from'),
              label: 'From',
              value: widget.filters.startedOnOrAfter,
              onSelected: (date) => _emit(
                widget.filters.copyWith(
                  startedOnOrAfter: startOfLocalDay(date),
                ),
                immediate: true,
              ),
              onClear: () => _emit(
                widget.filters.copyWith(clearStartedOnOrAfter: true),
                immediate: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DateFilterButton(
              key: const Key('history_filter_date_to'),
              label: 'To',
              value: widget.filters.startedOnOrBefore,
              onSelected: (date) => _emit(
                widget.filters.copyWith(startedOnOrBefore: endOfLocalDay(date)),
                immediate: true,
              ),
              onClear: () => _emit(
                widget.filters.copyWith(clearStartedOnOrBefore: true),
                immediate: true,
              ),
            ),
          ),
        ],
      ),
      if (widget.tags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Tags', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          key: const Key('history_filter_tags'),
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final tag in widget.tags)
              FilterChip(
                key: Key('history_filter_tag_${tag.id}'),
                label: Text(tag.name),
                selected: widget.filters.tagIds.contains(tag.id),
                onSelected: (_) =>
                    _emit(widget.filters.toggleTagId(tag.id), immediate: true),
              ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              key: const Key('history_filter_taste_min'),
              initialValue: widget.filters.minTasteScore,
              decoration: const InputDecoration(
                labelText: 'Min taste',
                isDense: true,
              ),
              items: _tasteScoreItems,
              onChanged: (value) {
                if (value == null) {
                  _emit(
                    widget.filters.copyWith(clearMinTasteScore: true),
                    immediate: true,
                  );
                } else {
                  _emit(
                    widget.filters.copyWith(minTasteScore: value),
                    immediate: true,
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const Key('history_filter_peak_min'),
              controller: _minPeakController,
              decoration: const InputDecoration(
                labelText: 'Min peak (bar)',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: _onMinPeakChanged,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('history_filter_more_toggle'),
          onPressed: () => setState(() => _moreExpanded = !_moreExpanded),
          icon: Icon(
            _moreExpanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          label: Text(_moreExpanded ? 'Fewer filters' : 'More filters'),
        ),
      ),
      if (_moreExpanded) ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('history_filter_peak_max'),
                controller: _maxPeakController,
                decoration: const InputDecoration(
                  labelText: 'Max peak (bar)',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: _onMaxPeakChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('history_filter_duration_min'),
                controller: _minDurationController,
                decoration: const InputDecoration(
                  labelText: 'Min time (s)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onMinDurationChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('history_filter_duration_max'),
                controller: _maxDurationController,
                decoration: const InputDecoration(
                  labelText: 'Max time (s)',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onMaxDurationChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('history_filter_grind_min'),
                controller: _minGrindController,
                decoration: const InputDecoration(
                  labelText: 'Min grind',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: _onMinGrindChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('history_filter_grind_max'),
                controller: _maxGrindController,
                decoration: const InputDecoration(
                  labelText: 'Max grind',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                onChanged: _onMaxGrindChanged,
              ),
            ),
          ],
        ),
      ],
    ];
  }

  void _clearAllFilters() {
    _debounce?.cancel();
    _beanController.clear();
    _minPeakController.clear();
    _maxPeakController.clear();
    _minDurationController.clear();
    _maxDurationController.clear();
    _minGrindController.clear();
    _maxGrindController.clear();
    widget.onChanged(ShotListFilters.empty);
  }

  static bool _hiddenFiltersAreActive(ShotListFilters filters) {
    return filters.startedOnOrAfter != null ||
        filters.startedOnOrBefore != null ||
        filters.minTasteScore != null ||
        filters.minPeakPressureBar != null ||
        filters.maxPeakPressureBar != null ||
        filters.minDurationMs != null ||
        filters.maxDurationMs != null ||
        filters.minGrindSetting != null ||
        filters.maxGrindSetting != null ||
        filters.tagIds.isNotEmpty;
  }

  void _onMinPeakChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _emit(widget.filters.copyWith(clearMinPeakPressureBar: true));
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    _emit(widget.filters.copyWith(minPeakPressureBar: parsed));
  }

  void _onMaxPeakChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _emit(widget.filters.copyWith(clearMaxPeakPressureBar: true));
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    _emit(widget.filters.copyWith(maxPeakPressureBar: parsed));
  }

  void _onMinDurationChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _emit(widget.filters.copyWith(clearMinDurationMs: true));
      return;
    }
    final sec = int.tryParse(trimmed);
    if (sec == null) {
      return;
    }
    _emit(widget.filters.copyWith(minDurationMs: sec * 1000));
  }

  void _onMaxDurationChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _emit(widget.filters.copyWith(clearMaxDurationMs: true));
      return;
    }
    final sec = int.tryParse(trimmed);
    if (sec == null) {
      return;
    }
    _emit(widget.filters.copyWith(maxDurationMs: sec * 1000));
  }

  void _onMinGrindChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _emit(widget.filters.copyWith(clearMinGrindSetting: true));
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    _emit(widget.filters.copyWith(minGrindSetting: parsed));
  }

  void _onMaxGrindChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _emit(widget.filters.copyWith(clearMaxGrindSetting: true));
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return;
    }
    _emit(widget.filters.copyWith(maxGrindSetting: parsed));
  }

  static String _formatNumber(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String _formatDurationSec(int? ms) {
    if (ms == null) {
      return '';
    }
    return (ms / 1000).round().toString();
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    super.key,
    required this.label,
    required this.value,
    required this.onSelected,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final display = value == null ? 'Any' : _formatDate(value!);

    return OutlinedButton(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      onLongPress: value == null ? null : onClear,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('$label: $display'),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year;
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final List<DropdownMenuItem<int?>> _tasteScoreItems = [
  const DropdownMenuItem<int?>(value: null, child: Text('Any')),
  for (var score = 0; score <= 10; score++)
    DropdownMenuItem<int?>(value: score, child: Text('$score')),
];

/// Start of [date] in local time.
DateTime startOfLocalDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// End of [date] in local time.
DateTime endOfLocalDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
