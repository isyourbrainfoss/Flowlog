import 'package:flutter/material.dart';

/// Exposes the active brew bean from the shell top bar to descendant tabs.
class ActiveBeanScope extends InheritedWidget {
  const ActiveBeanScope({
    required this.name,
    this.beanId,
    required this.onActiveBeanChanged,
    required super.child,
    super.key,
  });

  final String name;

  /// Persisted bean id when the active bean exists in the database.
  final String? beanId;

  final void Function(String name, {String? beanId}) onActiveBeanChanged;

  static ActiveBeanScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ActiveBeanScope>();
  }

  @override
  bool updateShouldNotify(covariant ActiveBeanScope oldWidget) {
    return name != oldWidget.name || beanId != oldWidget.beanId;
  }
}