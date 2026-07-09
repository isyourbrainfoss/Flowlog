import 'package:flowlog/screens/more/backup.dart';
import 'package:flowlog/screens/more/export.dart';
import 'package:flowlog/screens/more/nextcloud_sync.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcut intents for the Flowlog shell.
class ToggleLiveShotIntent extends Intent {
  const ToggleLiveShotIntent();
}

class OpenExportIntent extends Intent {
  const OpenExportIntent();
}

/// Registry for live-tab handlers registered by [LiveScreen].
class FlowlogShortcutRegistry {
  Future<void> Function()? toggleLiveShot;
  Future<void> Function()? startDemoShot;

  void setToggleLiveShot(Future<void> Function()? handler) {
    toggleLiveShot = handler;
  }

  void setStartDemoShot(Future<void> Function()? handler) {
    startDemoShot = handler;
  }
}

/// Exposes the current tab and shortcut registry to descendant widgets.
class FlowlogShortcutsScope extends InheritedWidget {
  const FlowlogShortcutsScope({
    required this.currentTab,
    required this.registry,
    required super.child,
    super.key,
  });

  final AppTab currentTab;
  final FlowlogShortcutRegistry registry;

  static FlowlogShortcutsScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FlowlogShortcutsScope>();
  }

  static FlowlogShortcutsScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'FlowlogShortcutsScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(FlowlogShortcutsScope oldWidget) {
    return currentTab != oldWidget.currentTab ||
        registry != oldWidget.registry;
  }
}

/// Opens the Nextcloud WebDAV sync settings screen.
void openNextcloudSyncScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Nextcloud sync')),
        body: const NextcloudSyncScreen(),
      ),
    ),
  );
}

/// Opens the full backup export/import screen.
void openBackupScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Backup & restore')),
        body: const BackupScreen(),
      ),
    ),
  );
}

/// Opens the batch CSV export screen (shared with More → Export shots).
void openExportScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Export shots')),
        body: const ExportScreen(),
      ),
    ),
  );
}

class _ToggleLiveShotAction extends ContextAction<ToggleLiveShotIntent> {
  _ToggleLiveShotAction(this.registry);

  final FlowlogShortcutRegistry registry;

  @override
  Object? invoke(ToggleLiveShotIntent intent, [BuildContext? context]) {
    if (context == null) {
      return null;
    }

    final scope = FlowlogShortcutsScope.maybeOf(context);
    if (scope?.currentTab != AppTab.live) {
      return null;
    }

    final toggle = registry.toggleLiveShot;
    if (toggle != null) {
      toggle();
    }
    return null;
  }
}

class _OpenExportAction extends ContextAction<OpenExportIntent> {
  @override
  Object? invoke(OpenExportIntent intent, [BuildContext? context]) {
    if (context != null) {
      openExportScreen(context);
    }
    return null;
  }
}

/// Desktop keyboard shortcuts: Space toggles live shot, Ctrl+E opens export.
class FlowlogShortcuts extends StatefulWidget {
  const FlowlogShortcuts({
    required this.registry,
    required this.currentTab,
    required this.child,
    super.key,
  });

  final FlowlogShortcutRegistry registry;
  final AppTab currentTab;
  final Widget child;

  @override
  State<FlowlogShortcuts> createState() => _FlowlogShortcutsState();
}

class _FlowlogShortcutsState extends State<FlowlogShortcuts> {
  late final Map<Type, Action<Intent>> _actions;

  @override
  void initState() {
    super.initState();
    _actions = <Type, Action<Intent>>{
      ToggleLiveShotIntent: _ToggleLiveShotAction(widget.registry),
      OpenExportIntent: _OpenExportAction(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FlowlogShortcutsScope(
      currentTab: widget.currentTab,
      registry: widget.registry,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.space): ToggleLiveShotIntent(),
          SingleActivator(LogicalKeyboardKey.keyE, control: true):
              OpenExportIntent(),
        },
        child: Actions(
          actions: _actions,
          child: Focus(
            autofocus: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}