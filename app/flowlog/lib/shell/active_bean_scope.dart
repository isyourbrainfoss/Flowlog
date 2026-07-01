import 'package:flutter/material.dart';

/// Exposes the active brew bean name from the shell top bar to descendant tabs.
class ActiveBeanScope extends InheritedWidget {
  const ActiveBeanScope({
    required this.name,
    required this.onNameChanged,
    required super.child,
    super.key,
  });

  final String name;
  final ValueChanged<String> onNameChanged;

  static ActiveBeanScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveBeanScope>();
  }

  @override
  bool updateShouldNotify(covariant ActiveBeanScope oldWidget) {
    return name != oldWidget.name;
  }
}