import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Shows saved pressure profiles for selection.
Future<SavedProfile?> showProfilePickerDialog({
  required BuildContext context,
  ProfileRepository? profileRepository,
  String title = 'Choose profile',
}) async {
  final repository = profileRepository ?? await _openProfileRepository();
  final profiles = await repository.listProfiles();
  if (!context.mounted) {
    return null;
  }

  if (profiles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No saved profiles yet — build one in the Simulator'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return null;
  }

  return showDialog<SavedProfile>(
    context: context,
    builder: (dialogContext) => _ProfilePickerDialog(
      title: title,
      profiles: profiles,
      profileRepository: repository,
    ),
  );
}

Future<ProfileRepository> _openProfileRepository() async {
  final database = await openFlowlogDatabase();
  return ProfileRepository(database);
}

class _ProfilePickerDialog extends StatefulWidget {
  const _ProfilePickerDialog({
    required this.title,
    required this.profiles,
    required this.profileRepository,
  });

  final String title;
  final List<SavedProfile> profiles;
  final ProfileRepository profileRepository;

  @override
  State<_ProfilePickerDialog> createState() => _ProfilePickerDialogState();
}

class _ProfilePickerDialogState extends State<_ProfilePickerDialog> {
  late Future<List<SavedProfile>> _profilesFuture;

  @override
  void initState() {
    super.initState();
    _profilesFuture = _loadProfilesWithSamples();
  }

  Future<List<SavedProfile>> _loadProfilesWithSamples() async {
    final loaded = <SavedProfile>[];
    for (final profile in widget.profiles) {
      final withSamples =
          await widget.profileRepository.getProfileWithSamples(profile.id);
      if (withSamples != null && withSamples.pressureSamples.isNotEmpty) {
        loaded.add(withSamples);
      }
    }
    return loaded;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('profile_picker_dialog'),
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<SavedProfile>>(
          future: _profilesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final profiles = snapshot.data ?? const <SavedProfile>[];
            if (profiles.isEmpty) {
              return const Text(
                'No profiles with pressure curves found. '
                'Export a shot or build one in the Simulator.',
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final sampleCount = profile.pressureSamples.length;
                return ListTile(
                  key: Key('profile_picker_${profile.id}'),
                  title: Text(profile.name),
                  subtitle: Text(
                    '$sampleCount points · '
                    '${_formatCreatedAt(profile.createdAt)}',
                  ),
                  onTap: () => Navigator.pop(context, profile),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static String _formatCreatedAt(DateTime createdAt) {
    final local = createdAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}