import 'package:flutter/material.dart';

/// Notifies listeners when the local shot store changes (save, delete, sync).
class ShotEventsNotifier extends ChangeNotifier {
  void notifyShotsChanged() {
    notifyListeners();
  }
}

/// Provides [ShotEventsNotifier] to screens that read or write shots.
class ShotEventsScope extends InheritedNotifier<ShotEventsNotifier> {
  const ShotEventsScope({
    required ShotEventsNotifier notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static ShotEventsNotifier? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ShotEventsScope>()
        ?.notifier;
  }
}