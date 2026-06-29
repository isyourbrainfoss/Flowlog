import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flutter/material.dart';

/// Adaptive app shell: collapsed rail, icon rail, or labeled sidebar by width.
class FlowlogShell extends StatefulWidget {
  const FlowlogShell({super.key, this.initialTab = AppTab.live});

  final AppTab initialTab;

  @override
  State<FlowlogShell> createState() => _FlowlogShellState();
}

class _FlowlogShellState extends State<FlowlogShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = appDestinations
        .indexWhere((destination) => destination.tab == widget.initialTab);
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final destination = appDestinations[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useSidebar = width >= ShellBreakpoints.sidebar;
        final collapsedRail = width < ShellBreakpoints.collapsedRail;

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                extended: useSidebar,
                minWidth: collapsedRail ? 56 : 72,
                minExtendedWidth: 200,
                labelType: useSidebar
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.none,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppBar(
                      title: Text(destination.label),
                    ),
                    Expanded(child: destination.screen),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}