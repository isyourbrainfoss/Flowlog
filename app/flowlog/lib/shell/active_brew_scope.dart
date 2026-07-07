import 'package:flutter/material.dart';

/// Tracks whether a live brew recording is in progress across tab switches.
class ActiveBrewScope extends InheritedNotifier<ActiveBrewNotifier> {
  const ActiveBrewScope({
    required ActiveBrewNotifier notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static ActiveBrewNotifier? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ActiveBrewScope>()
        ?.notifier;
  }
}

/// Notifies listeners when live recording state changes.
class ActiveBrewNotifier extends ChangeNotifier {
  bool _isBrewing = false;

  bool get isBrewing => _isBrewing;

  void setBrewing(bool value) {
    if (_isBrewing == value) {
      return;
    }
    _isBrewing = value;
    notifyListeners();
  }
}