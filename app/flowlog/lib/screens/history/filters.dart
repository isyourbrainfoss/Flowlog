import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Filter controls for the history shot list.
class HistoryFiltersPanel extends StatefulWidget {
  const HistoryFiltersPanel({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final ShotListFilters filters;
  final ValueChanged<ShotListFilters> onChanged;

  @override
  State<HistoryFiltersPanel> createState() => _HistoryFiltersPanelState();
}

class _HistoryFiltersPanelState extends State<HistoryFiltersPanel> {
  late final TextEditingController _beanController;
  late final TextEditingController _peakController;

  @override
  void initState() {
    super.initState();
    _beanController = TextEditingController(text: widget.filters.beanQuery);
    _peakController = TextEditingController(
      text: _formatPeakInput(widget.filters.minPeakPressureBar),
    );
  }

  @override
  void didUpdateWidget(covariant HistoryFiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filters.beanQuery != _beanController.text) {
      _beanController.text = widget.filters.beanQuery;
    }
    final peakText = _formatPeakInput(widget.filters.minPeakPressureBar);
    if (peakText != _peakController.text) {
      _peakController.text = peakText;
    }
  }

  @override
  void dispose() {
    _beanController.dispose();
    _peakController.dispose();
    super.dispose();
  }

  void _emit(ShotListFilters filters) {
    widget.onChanged(filters);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filters', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              key: const Key('history_filter_bean'),
              controller: _beanController,
              decoration: const InputDecoration(
                labelText: 'Bean name or id',
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) =>
                  _emit(widget.filters.copyWith(beanQuery: value)),
            ),
            const SizedBox(height: 8),
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
                    ),
                    onClear: () => _emit(
                      widget.filters.copyWith(clearStartedOnOrAfter: true),
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
                      widget.filters.copyWith(
                        startedOnOrBefore: endOfLocalDay(date),
                      ),
                    ),
                    onClear: () => _emit(
                      widget.filters.copyWith(clearStartedOnOrBefore: true),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    key: const Key('history_filter_taste_min'),
                    value: widget.filters.minTasteScore,
                    decoration: const InputDecoration(
                      labelText: 'Min taste',
                      isDense: true,
                    ),
                    items: _tasteScoreItems,
                    onChanged: (value) {
                      if (value == null) {
                        _emit(
                          widget.filters.copyWith(clearMinTasteScore: true),
                        );
                      } else {
                        _emit(widget.filters.copyWith(minTasteScore: value));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('history_filter_peak_min'),
                    controller: _peakController,
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
                    onChanged: _onPeakChanged,
                  ),
                ),
              ],
            ),
            if (widget.filters.isActive) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('history_filter_clear'),
                  onPressed: () {
                    _beanController.clear();
                    _peakController.clear();
                    _emit(ShotListFilters.empty);
                  },
                  child: const Text('Clear filters'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onPeakChanged(String value) {
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

  static String _formatPeakInput(double? value) {
    if (value == null) {
      return '';
    }
    return value.toString();
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
  const DropdownMenuItem<int?>(
    value: null,
    child: Text('Any'),
  ),
  for (var score = 0; score <= 10; score++)
    DropdownMenuItem<int?>(
      value: score,
      child: Text('$score'),
    ),
];

/// Start of [date] in local time.
DateTime startOfLocalDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

/// End of [date] in local time.
DateTime endOfLocalDay(DateTime date) {
  return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}