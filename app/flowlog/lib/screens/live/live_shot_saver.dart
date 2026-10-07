import 'dart:async';

import 'package:flowlog/location/brew_gps.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/live_brew_complete_overlay.dart';
import 'package:flowlog/screens/live/live_repositories.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog/shell/shot_events.dart';
import 'package:flowlog/sync/sync_feedback.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Auto-save / edit / discard flows for shots recorded on Live.
///
/// Owns the "was this session saved" bookkeeping. Inputs that can change
/// while a save is awaiting (repeat prefill, annotations, target curve,
/// widget callbacks) are read through resolvers at the moment they are used.
/// Every flow takes the Live screen's [BuildContext] and stops once it
/// unmounts.
class LiveShotSaver {
  LiveShotSaver({
    required this.repositories,
    required this.brewLocationStore,
    required this.brewGpsCapture,
    required this.banner,
    required this.confettiController,
    required this.resolveController,
    required this.resolveInitialMetadata,
    required this.resolveAnnotations,
    required this.resolveTargetPressureSamples,
    required this.resolveIdGenerator,
    required this.resolveOnShotSaved,
    required this.resolveShotEvents,
    required this.onStateChanged,
  });

  final LiveRepositories repositories;
  final BrewLocationStore brewLocationStore;
  final BrewGpsCapture brewGpsCapture;
  final BrewCompleteBannerController banner;
  final ConfettiController confettiController;
  final LiveShotController? Function() resolveController;
  final ShotMetadata? Function() resolveInitialMetadata;
  final List<ShotAnnotation> Function() resolveAnnotations;
  final List<ShotSample> Function() resolveTargetPressureSamples;
  final ShotIdGenerator Function() resolveIdGenerator;
  final void Function(Shot shot)? Function() resolveOnShotSaved;
  final ShotEventsNotifier? Function() resolveShotEvents;

  /// Called where Live must rebuild (save started/finished).
  final VoidCallback onStateChanged;

  bool _saving = false;
  bool _savedCurrent = false;
  String? _lastSavedShotId;

  /// True while an auto-save is in flight.
  bool get isSaving => _saving;

  /// True once the current session has been saved (hides "Save shot").
  bool get savedCurrent => _savedCurrent;

  /// Id of the shot auto-saved for the current session, if any.
  String? get lastSavedShotId => _lastSavedShotId;

  /// Forget the previous session (new controller or new brew).
  void resetForNewSession() {
    _savedCurrent = false;
    _lastSavedShotId = null;
  }

  /// Persists the stopped session with inferred metadata, then celebrates,
  /// shows the brew-complete banner, and kicks off sync.
  Future<void> autoSaveStoppedSession(BuildContext context) async {
    final controller = resolveController();
    if (controller == null ||
        !controller.canSaveShot ||
        _saving ||
        _savedCurrent) {
      return;
    }

    final startedAt = controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    _savedCurrent = true;
    _saving = true;
    onStateChanged();
    try {
      final repository = await repositories.shots();
      if (!context.mounted) {
        return;
      }

      final activeBean = ActiveBeanScope.maybeOf(context);
      final locationSettings = await brewLocationStore.loadSettings();
      BrewGpsPosition? gps;
      if (locationSettings.autoGpsEnabled) {
        gps = await brewGpsCapture.captureCurrentPosition();
      }
      final beanRepository = await repositories.beans();
      if (!context.mounted) {
        return;
      }

      final targetSamples = resolveTargetPressureSamples();
      final shot = await runAutoSaveFlow(
        context: context,
        repository: repository,
        shotRepository: repository,
        samples: controller.samples,
        startedAt: startedAt,
        endedAt: controller.sessionEndedAt,
        initialMetadata: resolveInitialMetadata(),
        beanRepository: beanRepository,
        activeBeanName: activeBean?.name,
        activeBeanId: activeBean?.beanId,
        annotations: resolveAnnotations(),
        location: locationSettings.currentLocation,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        autoStartPressureBar: controller.autoStartPressureBar,
        targetPressureSamples: targetSamples,
        idGenerator: resolveIdGenerator(),
        // Banner owns post-brew actions — skip snackbar so it does not
        // fight the bottom nav / Live controls after immersive ends.
        showSavedSnackBar: false,
        onSaved: (saved) {
          _lastSavedShotId = saved.id;
          _savedCurrent = true;
          resolveOnShotSaved()?.call(saved);
        },
        onAddNotes: (saved) => addNotesToSavedShot(context, saved),
        onDiscard: (saved) => discardSavedShot(context, saved),
      );

      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: shot,
        confettiController: confettiController,
      );

      if (shot != null) {
        if (context.mounted) {
          banner.show(BrewSummary.fromShot(shot));
          _savedCurrent = true;
        }
        resolveShotEvents()?.notifyShotsChanged();
        final database = await repositories.database();
        if (!context.mounted) {
          return;
        }
        unawaited(syncIfEnabledWithFeedback(context, database: database));
      }
    } finally {
      _saving = false;
      if (context.mounted) {
        onStateChanged();
      }
    }
  }

  /// Manual "Save shot" for a stopped session that was not auto-saved.
  Future<void> saveCurrentSession(BuildContext context) async {
    final controller = resolveController();
    if (controller == null || !controller.canSaveShot || _savedCurrent) {
      return;
    }
    await autoSaveStoppedSession(context);
  }

  /// Opens the metadata sheet for an already-saved [shot].
  Future<void> addNotesToSavedShot(BuildContext context, Shot shot) async {
    final repository = await repositories.shots();
    if (!context.mounted) {
      return;
    }

    final beanRepository = await repositories.beans();
    if (!context.mounted) {
      return;
    }

    final updated = await runAddNotesFlow(
      context: context,
      repository: repository,
      beanRepository: beanRepository,
      shot: shot,
      onSaved: resolveOnShotSaved(),
    );

    if (updated != null) {
      // Edit done — drop the Live "Edit" banner; History still has full edit.
      if (_lastSavedShotId == shot.id || _lastSavedShotId == updated.id) {
        banner.dismiss();
      }
      resolveShotEvents()?.notifyShotsChanged();
      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: updated,
        confettiController: confettiController,
      );
      final database = await repositories.database();
      if (!context.mounted) {
        return;
      }
      unawaited(syncIfEnabledWithFeedback(context, database: database));
    }
  }

  /// Banner "Edit": reopens the metadata sheet for the auto-saved shot.
  Future<void> editLastSavedShot(BuildContext context) async {
    if (_lastSavedShotId == null) return;
    final repository = await repositories.shots();
    if (!context.mounted) return;
    final shot = await repository.getShotWithSamples(_lastSavedShotId!);
    if (shot == null || !context.mounted) return;
    await addNotesToSavedShot(context, shot);
  }

  /// Banner "Discard": deletes the auto-saved shot [id].
  Future<void> discardAutoSavedShotById(BuildContext context, String id) async {
    final repository = await repositories.shots();
    if (!context.mounted) {
      return;
    }
    final shot = await repository.getShotById(id);
    if (shot == null) {
      await repository.deleteShot(id);
      _lastSavedShotId = null;
      _savedCurrent = false;
      banner.dismiss();
      resolveShotEvents()?.notifyShotsChanged();
      return;
    }
    if (!context.mounted) {
      // Live is gone: nothing to delete from here, just drop the banner.
      banner.dismiss();
      return;
    }
    await discardSavedShot(context, shot);
    banner.dismiss();
  }

  /// Deletes [shot] and confirms with a snackbar.
  Future<void> discardSavedShot(BuildContext context, Shot shot) async {
    final repository = await repositories.shots();
    if (!context.mounted) {
      return;
    }
    await repository.deleteShot(shot.id);
    if (_lastSavedShotId == shot.id) {
      _lastSavedShotId = null;
      _savedCurrent = false;
    }
    resolveShotEvents()?.notifyShotsChanged();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('shot_discarded_snackbar'),
          content: Text('Shot discarded'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
