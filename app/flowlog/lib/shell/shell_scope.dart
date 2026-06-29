import 'package:flowlog/shell/app_destinations.dart';
import 'package:flutter/material.dart';

/// Shell-level callbacks exposed to descendant routes (e.g. repeat shot → Live).
class FlowlogShellScope extends InheritedWidget {
  const FlowlogShellScope({
    required this.switchTab,
    required super.child,
    super.key,
  });

  final void Function(AppTab tab) switchTab;

  static FlowlogShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FlowlogShellScope>();
  }

  @override
  bool updateShouldNotify(covariant FlowlogShellScope oldWidget) {
    return switchTab != oldWidget.switchTab;
  }
}