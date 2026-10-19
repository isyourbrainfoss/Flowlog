import 'package:flowlog/shell/app_destinations.dart';
import 'package:flutter/material.dart';

/// Shell-level callbacks exposed to descendant routes (e.g. repeat shot → Live).
///
/// The shell lives *below* the app's root [Navigator] (it is
/// `MaterialApp.home`), so screens pushed with `Navigator.of(context).push`
/// from More (Target brew, Sensor diagnostics, …) and modal sheets are not
/// descendants of this widget. [maybeOf] therefore falls back to the shell
/// that is currently mounted, so "Build in Simulator", "Try demo shot" and
/// similar actions keep working from pushed routes.
class FlowlogShellScope extends InheritedWidget {
  const FlowlogShellScope({
    required this.switchTab,
    required super.child,
    super.key,
  });

  final void Function(AppTab tab) switchTab;

  static MountedScopeTracker? _mounted;

  static FlowlogShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FlowlogShellScope>() ??
        _mounted?.widget as FlowlogShellScope?;
  }

  @override
  InheritedElement createElement() => MountedScopeTracker(
    this,
    register: (element) => _mounted = element,
    unregister: (element) {
      if (identical(_mounted, element)) {
        _mounted = null;
      }
    },
  );

  @override
  bool updateShouldNotify(covariant FlowlogShellScope oldWidget) {
    return switchTab != oldWidget.switchTab;
  }
}

/// [InheritedElement] that reports when it is mounted / unmounted so a scope
/// can be found from routes that are not its descendants.
class MountedScopeTracker extends InheritedElement {
  MountedScopeTracker(
    super.widget, {
    required this.register,
    required this.unregister,
  });

  final void Function(MountedScopeTracker element) register;
  final void Function(MountedScopeTracker element) unregister;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    register(this);
  }

  @override
  void unmount() {
    unregister(this);
    super.unmount();
  }
}
