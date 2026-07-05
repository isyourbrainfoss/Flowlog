import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;

/// Default active bean label shown in the top bar.
const String kDefaultBeanName = 'House Blend';

/// Result from the top-bar active bean picker.
typedef ActiveBeanPickerResult = ({String name, String? beanId});

/// Adaptive shell top bar: active bean name and compact sensor status icons.
class FlowlogTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlowlogTopBar({
    super.key,
    required this.beanName,
    this.loadBeans,
    this.onActiveBeanChanged,
    this.pressensorState = ConnectionState.disconnected,
    this.scaleState = ConnectionState.disconnected,
  });

  final String beanName;
  final Future<List<Bean>> Function()? loadBeans;
  final void Function(String name, {String? beanId})? onActiveBeanChanged;
  final ConnectionState pressensorState;
  final ConnectionState scaleState;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('top_bar_bean_name'),
                    onTap: () => _showBeanNameDialog(context),
                    borderRadius:
                        BorderRadius.circular(FlowlogColors.cardRadius),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.coffee_outlined,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              beanName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SensorConnectionIcon(
                  key: const Key('top_bar_prs_status'),
                  label: 'Pressensor PRS',
                  icon: Icons.speed,
                  state: pressensorState,
                  onTap: () => _openSensorsScreen(context),
                ),
                const SizedBox(width: 4),
                SensorConnectionIcon(
                  key: const Key('top_bar_scale_status'),
                  label: 'Decent Scale',
                  icon: Icons.scale,
                  state: scaleState,
                  onTap: () => _openSensorsScreen(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSensorsScreen(BuildContext context) {
    FlowlogShellScope.maybeOf(context)?.switchTab(AppTab.more);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Sensors')),
          body: const SensorsScreen(),
        ),
      ),
    );
  }

  Future<void> _showBeanNameDialog(BuildContext context) async {
    final updated = await showDialog<ActiveBeanPickerResult>(
      context: context,
      builder: (dialogContext) => _BeanNameEditDialog(
        initialName: beanName,
        loadBeans: loadBeans ?? () async => const <Bean>[],
      ),
    );
    if (updated == null || updated.name.isEmpty) {
      return;
    }
    if (updated.beanId != null || updated.name != beanName) {
      onActiveBeanChanged?.call(updated.name, beanId: updated.beanId);
    }
  }
}

class _BeanNameEditDialog extends StatefulWidget {
  const _BeanNameEditDialog({
    required this.initialName,
    required this.loadBeans,
  });

  final String initialName;
  final Future<List<Bean>> Function() loadBeans;

  @override
  State<_BeanNameEditDialog> createState() => _BeanNameEditDialogState();
}

class _BeanNameEditDialogState extends State<_BeanNameEditDialog> {
  late final TextEditingController _beanController;
  List<Bean> _beans = const [];
  bool _beansReady = false;
  String? _selectedBeanId;

  @override
  void initState() {
    super.initState();
    _beanController = TextEditingController(text: widget.initialName);
    _loadBeans();
  }

  Future<void> _loadBeans() async {
    final beans = await widget.loadBeans();
    if (!mounted) {
      return;
    }
    setState(() {
      _beans = beans;
      _beansReady = true;
    });
  }

  @override
  void dispose() {
    _beanController.dispose();
    super.dispose();
  }

  ActiveBeanPickerResult _buildResult() {
    return (name: _beanController.text.trim(), beanId: _selectedBeanId);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Active bean'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This is the bean you are dialing in right now. New shots '
            'prefill with this name until you change it.',
            style: Theme.of(context).textTheme.bodySmall,
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
                key: const Key('top_bar_bean_edit_field'),
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                enabled: _beansReady,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Bean',
                  hintText: 'e.g. House Blend',
                  helperText:
                      'Pick a saved bag or type a new name to create one',
                ),
                onChanged: (value) {
                  _beanController.text = value;
                  _selectedBeanId = null;
                },
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('top_bar_bean_save'),
          onPressed: () => Navigator.pop(context, _buildResult()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Compact top-bar icon indicating sensor [ConnectionState].
class SensorConnectionIcon extends StatelessWidget {
  const SensorConnectionIcon({
    super.key,
    required this.label,
    required this.icon,
    required this.state,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final ConnectionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (tooltip, color, background) = _styleForState(scheme, state);

    final child = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: 20, color: color),
    );

    return Tooltip(
      message: onTap != null
          ? '$label: $tooltip — tap to open Sensors'
          : '$label: $tooltip',
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
              child: child,
            ),
    );
  }

  (String, Color, Color) _styleForState(
    ColorScheme scheme,
    ConnectionState state,
  ) {
    return switch (state) {
      ConnectionState.connected => (
          'Connected',
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        ),
      ConnectionState.disconnected => (
          'Disconnected',
          scheme.onSurfaceVariant,
          scheme.surface,
        ),
      ConnectionState.connecting => (
          'Connecting',
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
        ),
      ConnectionState.error => (
          'Error',
          scheme.error,
          scheme.error.withValues(alpha: 0.16),
        ),
    };
  }
}