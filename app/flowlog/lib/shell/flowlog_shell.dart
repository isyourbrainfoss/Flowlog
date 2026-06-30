import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/shell/top_bar.dart';
import 'package:flutter/material.dart';

/// Adaptive app shell: bottom bar when narrow/short, labeled sidebar when wide.
class FlowlogShell extends StatefulWidget {
  const FlowlogShell({
    super.key,
    this.initialTab = AppTab.live,
    this.repeatShotController,
  });

  final AppTab initialTab;

  /// Optional repeat-shot controller for tests.
  final RepeatShotController? repeatShotController;

  @override
  State<FlowlogShell> createState() => _FlowlogShellState();
}

class _FlowlogShellState extends State<FlowlogShell> {
  late int _selectedIndex;
  String _beanName = kDefaultBeanName;
  final FlowlogShortcutRegistry _shortcutRegistry = FlowlogShortcutRegistry();
  late final RepeatShotController _repeatShotController;
  late final bool _ownsRepeatShotController;

  @override
  void initState() {
    super.initState();
    _ownsRepeatShotController = widget.repeatShotController == null;
    _repeatShotController =
        widget.repeatShotController ?? RepeatShotController();
    _selectedIndex = appDestinations
        .indexWhere((destination) => destination.tab == widget.initialTab);
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
  }

  @override
  void dispose() {
    if (_ownsRepeatShotController) {
      _repeatShotController.dispose();
    }
    super.dispose();
  }

  void _onBeanNameChanged(String name) {
    setState(() => _beanName = name);
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _switchTab(AppTab tab) {
    final index =
        appDestinations.indexWhere((destination) => destination.tab == tab);
    if (index < 0) {
      return;
    }
    setState(() => _selectedIndex = index);
  }

  bool _useBottomNav(BoxConstraints constraints) {
    return constraints.maxWidth < ShellBreakpoints.sidebar ||
        constraints.maxHeight < ShellBreakpoints.minRailHeight;
  }

  @override
  Widget build(BuildContext context) {
    final destination = appDestinations[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useBottomNav = _useBottomNav(constraints);
        // Keep a stable body tree so tab screens (e.g. Live) survive resize.
        final shell = Scaffold(
          body: Row(
            children: [
              if (!useBottomNav) ...[
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  extended: true,
                  minExtendedWidth: 200,
                  labelType: NavigationRailLabelType.none,
                  destinations: [
                    for (final item in appDestinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.icon),
                        label: Semantics(
                          label: item.semanticsLabel,
                          child: ExcludeSemantics(
                            child: Text(item.label),
                          ),
                        ),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                key: const ValueKey('shell-main-panel'),
                child: _ShellContent(
                  beanName: _beanName,
                  onBeanNameChanged: _onBeanNameChanged,
                  child: destination.screen,
                ),
              ),
            ],
          ),
          bottomNavigationBar: useBottomNav
              ? _FlowlogBottomBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                )
              : null,
        );

        return RepeatShotScope(
          controller: _repeatShotController,
          child: FlowlogShellScope(
            switchTab: _switchTab,
            child: FlowlogShortcuts(
              registry: _shortcutRegistry,
              currentTab: destination.tab,
              child: shell,
            ),
          ),
        );
      },
    );
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({
    required this.beanName,
    required this.onBeanNameChanged,
    required this.child,
  });

  final String beanName;
  final ValueChanged<String> onBeanNameChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTopBar =
            constraints.maxHeight >= ShellBreakpoints.minHeightForAppBar;

        if (!showTopBar) {
          // Ultra-compact: bottom nav ate most of the height — skip the top bar.
          return ClipRect(child: child);
        }

        final hub = SensorHubScope.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: hub,
              builder: (context, _) {
                return FlowlogTopBar(
                  beanName: beanName,
                  onBeanNameChanged: onBeanNameChanged,
                  pressensorState: hub.pressensorState,
                  scaleState: hub.scaleState,
                );
              },
            ),
            Expanded(child: ClipRect(child: child)),
          ],
        );
      },
    );
  }
}

/// Libadwaita-style bottom bar: icons only, easy thumb reach on phone.
class _FlowlogBottomBar extends StatelessWidget {
  const _FlowlogBottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      destinations: [
        for (final item in appDestinations)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon),
            label: item.semanticsLabel,
            tooltip: item.semanticsLabel,
          ),
      ],
    );
  }
}