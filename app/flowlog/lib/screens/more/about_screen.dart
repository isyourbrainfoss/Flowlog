import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Short release notes shown on the About screen for this marketing version.
const flowlogWhatsNew = '''
• Repeat shot from History now really loads the shot as the target on Live (before it only showed a message)
• "Try demo shot" (Sensor diagnostics) and Target brew → "Build in Simulator" work again; the latter opens the Simulator tab
• "Set as target brew" from a shot updates Live right away
• Number fields show decimals the way you type them — 18,5 stays 18,5 on Norwegian/German phones
• Simulator: loading a shot keeps its pre-infusion step and 9 bar hold; preview and saved targets hold the last pressure to the end; "12 bar" axis label no longer overlaps
• Live: the chart is no longer cut off when a target or brew-complete banner is shown
• After a shot: one Yield tile and no dash after every value
• The demo shot now ends by itself
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
