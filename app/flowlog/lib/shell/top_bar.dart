import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;

/// Default mock sensor connection states until BLE wiring replaces them.
const ConnectionState kMockPressensorState = ConnectionState.connected;
const ConnectionState kMockScaleState = ConnectionState.disconnected;

/// Default active bean label shown in the top bar.
const String kDefaultBeanName = 'House Blend';

/// Adaptive shell top bar: active bean name and compact sensor status icons.
class FlowlogTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FlowlogTopBar({
    super.key,
    required this.beanName,
    this.onBeanNameChanged,
    this.pressensorState = kMockPressensorState,
    this.scaleState = kMockScaleState,
  });

  final String beanName;
  final ValueChanged<String>? onBeanNameChanged;
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
                ),
                const SizedBox(width: 4),
                SensorConnectionIcon(
                  key: const Key('top_bar_scale_status'),
                  label: 'Decent Scale',
                  icon: Icons.scale,
                  state: scaleState,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBeanNameDialog(BuildContext context) async {
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _BeanNameEditDialog(initialName: beanName),
    );
    if (updated != null && updated.isNotEmpty && updated != beanName) {
      onBeanNameChanged?.call(updated);
    }
  }
}

class _BeanNameEditDialog extends StatefulWidget {
  const _BeanNameEditDialog({required this.initialName});

  final String initialName;

  @override
  State<_BeanNameEditDialog> createState() => _BeanNameEditDialogState();
}

class _BeanNameEditDialogState extends State<_BeanNameEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bean name'),
      content: TextField(
        key: const Key('top_bar_bean_edit_field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Bean',
          hintText: 'e.g. House Blend',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('top_bar_bean_save'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
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
  });

  final String label;
  final IconData icon;
  final ConnectionState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (tooltip, color, background) = _styleForState(scheme, state);

    return Tooltip(
      message: '$label: $tooltip',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(FlowlogColors.cardRadius),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 20, color: color),
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