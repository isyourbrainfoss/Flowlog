import 'dart:convert';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Strips identifying metadata while keeping the pressure curve shape.
SavedProfile anonymizeProfile(SavedProfile profile) {
  return SavedProfile(
    id: profile.id,
    name: profile.name,
    createdAt: profile.createdAt,
    pressureSamples: profile.pressureSamples,
  );
}

/// Builds a stub deep link encoding the anonymised profile payload.
String generateShareLink(SavedProfile profile) {
  final payload = jsonEncode(anonymizeProfile(profile).toJson());
  final hash = base64Url.encode(utf8.encode(payload));
  return 'flowlog://profile/$hash';
}

/// Copies [link] to the clipboard and shows confirmation feedback.
Future<void> copyShareLink(
  BuildContext context,
  String link, {
  String snackbarMessage = 'Profile link copied',
  ScaffoldMessengerState? messenger,
}) async {
  await Clipboard.setData(ClipboardData(text: link));
  final snackbarMessenger = messenger ?? ScaffoldMessenger.of(context);
  snackbarMessenger.showSnackBar(
    SnackBar(
      key: const Key('share_profile_snackbar'),
      content: Text(snackbarMessage),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Dialog for previewing and copying a community profile share link.
Future<void> showShareProfileDialog(
  BuildContext context,
  SavedProfile profile,
) async {
  final link = generateShareLink(profile);
  final theme = Theme.of(context);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final maxLinkHeight = MediaQuery.sizeOf(dialogContext).height * 0.35;

      return AlertDialog(
        key: const Key('share_profile_dialog'),
        title: const Text('Share profile'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share an anonymised pressure curve. Bean, shot, and personal '
                'notes are not included.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxLinkHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      link,
                      key: const Key('share_profile_link'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton.icon(
            key: const Key('share_profile_system_share'),
            onPressed: () async {
              await Share.share(link, subject: profile.name);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
          FilledButton.icon(
            key: const Key('share_profile_copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  key: Key('share_profile_snackbar'),
                  content: Text('Profile link copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
          ),
        ],
      );
    },
  );
}

/// App-bar action that opens the share-profile dialog.
class ShareProfileButton extends StatelessWidget {
  const ShareProfileButton({
    required this.profile,
    super.key,
  });

  /// Builds a share action from a saved shot (pressure curve + metadata).
  factory ShareProfileButton.fromShot(Shot shot) {
    return ShareProfileButton(
      profile: SavedProfile.fromShot(
        shot,
        id: shot.id,
      ),
    );
  }

  final SavedProfile profile;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('share_profile_button'),
      tooltip: 'Share profile',
      icon: const Icon(Icons.ios_share),
      onPressed: () => showShareProfileDialog(context, profile),
    );
  }
}