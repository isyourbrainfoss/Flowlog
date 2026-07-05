import 'dart:async';
import 'dart:io';

import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/shell/top_bar.dart';
import 'package:flowlog_core/flowlog_core.dart';
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
  String? _beanId;
  BeanRepository? _beanRepository;
  FlowlogDatabase? _database;
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
    unawaited(_loadActiveBeanAndSync());
  }

  Future<void> _loadActiveBeanAndSync() async {
    await _loadActiveBean();
    final database = _database;
    if (database != null) {
      unawaited(FlowlogSyncCoordinator.syncIfEnabled(database: database));
    }
  }

  Future<BeanRepository> _ensureBeanRepository() async {
    if (_beanRepository != null) {
      return _beanRepository!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _beanRepository = BeanRepository(_database!);
    return _beanRepository!;
  }

  Future<void> _loadActiveBean() async {
    final repository = await _ensureBeanRepository();
    final beans = await repository.listBeansByRecentUse();
    if (!mounted || beans.isEmpty) {
      return;
    }

    setState(() {
      _beanName = beans.first.name;
      _beanId = beans.first.id;
    });
  }

  @override
  void dispose() {
    if (_ownsRepeatShotController) {
      _repeatShotController.dispose();
    }
    _database?.close();
    super.dispose();
  }

  Future<void> _onBeanNameChanged(String name) async {
    final repository = await _ensureBeanRepository();
    final trimmed = name.trim();
    if (trimmed.isEmpty || !mounted) {
      return;
    }

    if (_beanId != null) {
      final existing = await repository.getBeanById(_beanId!);
      if (existing != null) {
        final updated = existing.copyWith(name: trimmed);
        await repository.updateBean(updated);
        setState(() {
          _beanName = updated.name;
        });
        return;
      }
    }

    final created = await repository.createBean(name: trimmed);
    if (!mounted) {
      return;
    }

    setState(() {
      _beanName = created.name;
      _beanId = created.id;
    });
  }

  Future<void> _handleActiveBeanChanged(String name, {String? beanId}) async {
    if (!mounted) {
      return;
    }

    if (beanId != null) {
      final repository = await _ensureBeanRepository();
      final bean = await repository.getBeanById(beanId);
      if (!mounted) {
        return;
      }
      if (bean != null) {
        setState(() {
          _beanName = bean.name;
          _beanId = bean.id;
        });
        return;
      }
    }

    await _onBeanNameChanged(name);
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
    final shortestSide = constraints.maxWidth < constraints.maxHeight
        ? constraints.maxWidth
        : constraints.maxHeight;
    // Phones in landscape exceed width 600 but should keep bottom nav.
    return shortestSide < ShellBreakpoints.sidebar ||
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
                  beanId: _beanId,
                  loadBeans: () => _ensureBeanRepository().then(
                    (repository) => repository.listBeansByRecentUse(),
                  ),
                  onActiveBeanChanged: (name, {beanId}) => unawaited(
                    _handleActiveBeanChanged(name, beanId: beanId),
                  ),
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
    required this.beanId,
    required this.loadBeans,
    required this.onActiveBeanChanged,
    required this.child,
  });

  final String beanName;
  final String? beanId;
  final Future<List<Bean>> Function() loadBeans;
  final void Function(String name, {String? beanId}) onActiveBeanChanged;
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

        return ActiveBeanScope(
          name: beanName,
          beanId: beanId,
          onActiveBeanChanged: onActiveBeanChanged,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListenableBuilder(
                listenable: hub,
                builder: (context, _) {
                  return FlowlogTopBar(
                    beanName: beanName,
                    loadBeans: loadBeans,
                    onActiveBeanChanged: onActiveBeanChanged,
                    pressensorState: hub.pressensorState,
                    scaleState: hub.scaleState,
                  );
                },
              ),
              Expanded(child: ClipRect(child: child)),
            ],
          ),
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