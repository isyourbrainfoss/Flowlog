import 'dart:async';
import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog/shell/active_brew_scope.dart';
import 'package:flowlog/shell/shot_events.dart';
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
    this.targetBrewController,
    this.autoStartController,
  });

  final AppTab initialTab;

  /// Optional repeat-shot controller for tests.
  final RepeatShotController? repeatShotController;

  /// Optional target-brew controller for tests.
  final TargetBrewController? targetBrewController;

  /// Optional auto-start controller for tests.
  final AutoStartSettingsController? autoStartController;

  @override
  State<FlowlogShell> createState() => _FlowlogShellState();
}

class _FlowlogShellState extends State<FlowlogShell> {
  late int _selectedIndex;
  String _beanName = '';
  String? _beanId;
  BeanRepository? _beanRepository;
  FlowlogDatabase? _database;
  final FlowlogShortcutRegistry _shortcutRegistry = FlowlogShortcutRegistry();
  late final RepeatShotController _repeatShotController;
  late final bool _ownsRepeatShotController;
  late final TargetBrewController _targetBrewController;
  late final bool _ownsTargetBrewController;
  late final AutoStartSettingsController _autoStartController;
  late final bool _ownsAutoStartController;
  late final ActiveBrewNotifier _activeBrewNotifier;
  late final ShotEventsNotifier _shotEventsNotifier;

  @override
  void initState() {
    super.initState();
    _ownsRepeatShotController = widget.repeatShotController == null;
    _repeatShotController =
        widget.repeatShotController ?? RepeatShotController();
    _ownsTargetBrewController = widget.targetBrewController == null;
    _targetBrewController =
        widget.targetBrewController ?? TargetBrewController();
    _ownsAutoStartController = widget.autoStartController == null;
    _autoStartController =
        widget.autoStartController ?? AutoStartSettingsController();
    _activeBrewNotifier = ActiveBrewNotifier();
    _shotEventsNotifier = ShotEventsNotifier();
    _selectedIndex = appDestinations
        .indexWhere((destination) => destination.tab == widget.initialTab);
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
    unawaited(_loadActiveBeanAndSync());
    unawaited(_loadTargetBrew());
    unawaited(_autoStartController.load());
  }

  Future<void> _loadActiveBeanAndSync() async {
    await _loadActiveBean();
    final database = _database;
    if (database != null) {
      unawaited(FlowlogSyncCoordinator.syncIfEnabled(database: database));
    }
  }

  Future<void> _loadTargetBrew() async {
    final database = _database ?? await openFlowlogDatabase();
    _database ??= database;
    await _targetBrewController.load(ProfileRepository(database));
  }

  Future<BeanRepository> _ensureBeanRepository() async {
    if (_beanRepository != null) {
      return _beanRepository!;
    }

    _database = await openFlowlogDatabase();
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
    if (_ownsTargetBrewController) {
      _targetBrewController.dispose();
    }
    if (_ownsAutoStartController) {
      _autoStartController.dispose();
    }
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
    if (index == _selectedIndex) {
      return;
    }

    final leavingLive = appDestinations[_selectedIndex].tab == AppTab.live;
    final brewing = _activeBrewNotifier.isBrewing;
    if (leavingLive && brewing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('brew_in_progress_snackbar'),
          content: Text(
            'Brew still recording — return to Live to stop and save',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }

    setState(() => _selectedIndex = index);
    _notifyHistoryRefreshIfNeeded(index);
  }

  void _switchTab(AppTab tab) {
    final index =
        appDestinations.indexWhere((destination) => destination.tab == tab);
    if (index < 0) {
      return;
    }
    setState(() => _selectedIndex = index);
    _notifyHistoryRefreshIfNeeded(index);
  }

  void _notifyHistoryRefreshIfNeeded(int index) {
    if (appDestinations[index].tab == AppTab.history) {
      _shotEventsNotifier.notifyShotsChanged();
    }
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
                ListenableBuilder(
                  listenable: _activeBrewNotifier,
                  builder: (context, _) {
                    return NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _onDestinationSelected,
                      extended: true,
                      minExtendedWidth: 200,
                      labelType: NavigationRailLabelType.none,
                      destinations: [
                        for (final item in appDestinations)
                          NavigationRailDestination(
                            icon: _TabIcon(
                              icon: item.icon,
                              showRecordingBadge: item.tab == AppTab.live &&
                                  _activeBrewNotifier.isBrewing,
                            ),
                            selectedIcon: _TabIcon(
                              icon: item.icon,
                              showRecordingBadge: item.tab == AppTab.live &&
                                  _activeBrewNotifier.isBrewing,
                            ),
                            label: Semantics(
                              label: item.semanticsLabel,
                              child: ExcludeSemantics(
                                child: Text(item.label),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
                  child: _PersistentTabStack(
                    index: _selectedIndex,
                    children: [
                      for (final item in appDestinations) item.screen,
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: useBottomNav
              ? _FlowlogBottomBar(
                  selectedIndex: _selectedIndex,
                  activeBrewNotifier: _activeBrewNotifier,
                  onDestinationSelected: _onDestinationSelected,
                )
              : null,
        );

        return ShotEventsScope(
          notifier: _shotEventsNotifier,
          child: ActiveBrewScope(
            notifier: _activeBrewNotifier,
            child: AutoStartSettingsScope(
              controller: _autoStartController,
              child: TargetBrewScope(
                controller: _targetBrewController,
                child: RepeatShotScope(
                  controller: _repeatShotController,
                  child: FlowlogShellScope(
                    switchTab: _switchTab,
                    child: FlowlogShortcuts(
                      registry: _shortcutRegistry,
                      currentTab: destination.tab,
                      child: shell,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps visited tabs alive so in-progress brews survive tab switches.
///
/// The Live tab (index 0) is always retained even before it is first shown.
class _PersistentTabStack extends StatefulWidget {
  const _PersistentTabStack({
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<_PersistentTabStack> createState() => _PersistentTabStackState();
}

class _PersistentTabStackState extends State<_PersistentTabStack> {
  static const int _liveTabIndex = 0;
  final Set<int> _retainedIndexes = {_liveTabIndex};

  @override
  void didUpdateWidget(covariant _PersistentTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _retainedIndexes
      ..add(_liveTabIndex)
      ..add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_retainedIndexes.contains(i))
            Offstage(
              offstage: i != widget.index,
              child: TickerMode(
                enabled: i == widget.index,
                child: widget.children[i],
              ),
            ),
      ],
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
                    pressensorBatteryPercent: hub.pressensorBatteryPercent,
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
    required this.activeBrewNotifier,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ActiveBrewNotifier activeBrewNotifier;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activeBrewNotifier,
      builder: (context, _) {
        return NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
            for (final item in appDestinations)
              NavigationDestination(
                icon: _TabIcon(
                  icon: item.icon,
                  showRecordingBadge: item.tab == AppTab.live &&
                      activeBrewNotifier.isBrewing,
                ),
                selectedIcon: _TabIcon(
                  icon: item.icon,
                  showRecordingBadge: item.tab == AppTab.live &&
                      activeBrewNotifier.isBrewing,
                ),
                label: item.semanticsLabel,
                tooltip: item.semanticsLabel,
              ),
          ],
        );
      },
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.showRecordingBadge,
  });

  final IconData icon;
  final bool showRecordingBadge;

  @override
  Widget build(BuildContext context) {
    if (!showRecordingBadge) {
      return Icon(icon);
    }

    final scheme = Theme.of(context).colorScheme;
    return Badge(
      key: const Key('live_recording_badge'),
      isLabelVisible: false,
      backgroundColor: scheme.error,
      smallSize: 10,
      child: Icon(icon),
    );
  }
}