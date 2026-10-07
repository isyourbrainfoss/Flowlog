import 'dart:async';

import 'package:flowlog/screens/live/brew_complete_banner.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Holds the post-brew summary shown over Live and auto-dismisses it.
class BrewCompleteBannerController extends ChangeNotifier {
  BrewCompleteBannerController({this.autoDismiss = defaultAutoDismiss});

  /// How long the banner stays up without interaction.
  static const Duration defaultAutoDismiss = Duration(seconds: 45);

  final Duration autoDismiss;

  BrewSummary? _summary;
  Timer? _dismissTimer;
  bool _disposed = false;

  /// Summary currently shown, or null when the banner is hidden.
  BrewSummary? get summary => _summary;

  bool get isVisible => _summary != null;

  /// Shows [summary] and (re)starts the auto-dismiss timer.
  void show(BrewSummary summary) {
    _summary = summary;
    notifyListeners();
    _dismissTimer?.cancel();
    _dismissTimer = Timer(autoDismiss, () {
      _dismissTimer = null;
      if (_summary != null) {
        _summary = null;
        notifyListeners();
      }
    });
  }

  /// Hides the banner (no-op when already hidden).
  ///
  /// Safe after [dispose]: a save/discard flow finishing after Live unmounts
  /// may still call this.
  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_summary != null) {
      _summary = null;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    super.dispose();
  }
}

/// Elevated post-brew banner stacked above Live content.
class LiveBrewCompleteOverlay extends StatelessWidget {
  const LiveBrewCompleteOverlay({
    super.key,
    required this.summary,
    required this.onDismiss,
    this.onEdit,
    this.onDiscard,
  });

  final BrewSummary summary;
  final VoidCallback onDismiss;
  final VoidCallback? onEdit;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('brew_complete_overlay'),
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Colors.black54,
      child: BrewCompleteBanner(
        summary: summary,
        onDismiss: onDismiss,
        onEdit: onEdit,
        onDiscard: onDiscard,
      ),
    );
  }
}
