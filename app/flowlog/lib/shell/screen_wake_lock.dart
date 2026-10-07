import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen awake only while [enabled] is true and the app is
/// in the foreground (e.g. during an active Live brew).
class ScreenWakeLock extends StatefulWidget {
  const ScreenWakeLock({
    required this.child,
    required this.enabled,
    super.key,
  });

  final Widget child;

  /// When true and the app is resumed, the wake lock is held.
  final bool enabled;

  @override
  State<ScreenWakeLock> createState() => _ScreenWakeLockState();
}

class _ScreenWakeLockState extends State<ScreenWakeLock>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncWakeLock());
  }

  @override
  void didUpdateWidget(covariant ScreenWakeLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      unawaited(_syncWakeLock());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_setWakeLock(enabled: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        unawaited(_syncWakeLock());
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _foreground = false;
        unawaited(_setWakeLock(enabled: false));
    }
  }

  Future<void> _syncWakeLock() {
    return _setWakeLock(enabled: widget.enabled && _foreground);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _setWakeLock({required bool enabled}) async {
  if (kIsWeb) {
    return;
  }

  try {
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  } on Object {
    // Some platforms (including widget tests) do not support wakelock.
  }
}
