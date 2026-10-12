import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Short release notes shown on the About screen for this marketing version.
const flowlogWhatsNew = '''
• Number fields accept comma decimals (e.g. 18,5 g) — dose, grind, yield, filters, beans, simulator
• Fix: values typed with a comma were silently dropped
''';

/// About tile content: marketing version, build number, and what's new.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.packageInfo});

  /// Optional override for tests.
  final PackageInfo? packageInfo;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    if (widget.packageInfo != null) {
      _info = widget.packageInfo;
    } else {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) {
          setState(() => _info = info);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final versionLabel = info == null
        ? '…'
        : '${info.version} (${info.buildNumber})';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Flowlog', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Version $versionLabel',
          key: const Key('about_version_label'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Personal coffee intelligence hub — live shot curves, history, '
          'and sensor tooling.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Text("What's new", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          flowlogWhatsNew.trim(),
          key: const Key('about_whats_new'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Text(
          'Android release tags remain build-N (CI run number). The APK '
          'versionName follows pubspec marketing version (e.g. 0.0.3); '
          'versionCode is the CI run number so Obtainium updates keep working.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

void openAboutScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('About')),
        body: const AboutScreen(),
      ),
    ),
  );
}
