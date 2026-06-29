import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/top_bar.dart';
import 'package:flutter/material.dart';

/// Adaptive app shell: bottom bar when narrow/short, labeled sidebar when wide.
class FlowlogShell extends StatefulWidget {
  const FlowlogShell({super.key, this.initialTab = AppTab.live});

  final AppTab initialTab;

  @override
  State<FlowlogShell> createState() => _FlowlogShellState();
}

class _FlowlogShellState extends State<FlowlogShell> {
  late int _selectedIndex;
  String _beanName = kDefaultBeanName;

  @override
  void initState() {
    super.initState();
    _selectedIndex = appDestinations
        .indexWhere((destination) => destination.tab == widget.initialTab);
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
  }

  void _onBeanNameChanged(String name) {
    setState(() => _beanName = name);
  }

  void _onDestinationSelected(int index) {
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
        if (_useBottomNav(constraints)) {
          return Scaffold(
            body: _ShellContent(
              beanName: _beanName,
              onBeanNameChanged: _onBeanNameChanged,
              child: destination.screen,
            ),
            bottomNavigationBar: _FlowlogBottomBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
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
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _ShellContent(
                  beanName: _beanName,
                  onBeanNameChanged: _onBeanNameChanged,
                  child: destination.screen,
                ),
              ),
            ],
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
            label: item.label,
          ),
      ],
    );
  }
}