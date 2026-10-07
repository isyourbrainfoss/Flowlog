import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Runs [FlowlogSyncCoordinator.syncIfEnabled] and surfaces the outcome in a
/// snackbar when the user is not on the Nextcloud settings screen.
Future<NextcloudSyncResult?> syncIfEnabledWithFeedback(
  BuildContext context, {
  FlowlogDatabase? database,
  bool force = false,
  bool showSuccess = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await FlowlogSyncCoordinator.syncIfEnabled(
    database: database,
    force: force,
  );

  if (result == null || messenger == null) {
    return result;
  }

  if (!result.success) {
    messenger.showSnackBar(
      SnackBar(
        key: const Key('sync_failure_snackbar'),
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : (result.error ?? 'Nextcloud sync failed'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
    return result;
  }

  if (showSuccess && result.message.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        key: const Key('sync_success_snackbar'),
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  return result;
}
