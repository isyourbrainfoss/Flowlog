import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the device screen awake while the Flowlog app is in the foreground.
class ScreenWakeLock extends StatefulWidget {
  const ScreenWakeLock({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<ScreenWakeLock> createState() => _ScreenWakeLockState();
}

class _ScreenWakeLockState extends State<ScreenWakeLock>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setWakeLock(enabled: true));
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
        unawaited(_setWakeLock(enabled: true));
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_setWakeLock(enabled: false));
    }
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