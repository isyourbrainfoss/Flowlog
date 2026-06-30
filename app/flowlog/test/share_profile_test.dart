import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog/screens/library/share_profile.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('anonymizeProfile', () {
    test('strips identifying metadata and keeps pressure curve', () {
      final profile = SavedProfile(
        id: 'profile-1',
        name: 'Morning repeat',
        createdAt: DateTime.utc(2026, 6, 29, 8),
        sourceShotId: 'shot-minimal-001',
        doseG: 18,
        yieldG: 36,
        grindSetting: 14,
        beanId: 'bean-house-blend',
        waterTempC: 93,
        pressureSamples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0),
          ShotSample(elapsedMs: 5000, pressureBar: 9),
        ],
      );

      final anonymized = anonymizeProfile(profile);

      expect(anonymized.id, profile.id);
      expect(anonymized.name, profile.name);
      expect(anonymized.createdAt, profile.createdAt);
      expect(anonymized.pressureSamples, profile.pressureSamples);
      expect(anonymized.sourceShotId, isNull);
      expect(anonymized.beanId, isNull);
      expect(anonymized.doseG, isNull);
      expect(anonymized.yieldG, isNull);
      expect(anonymized.grindSetting, isNull);
      expect(anonymized.waterTempC, isNull);
      expect(anonymized.toJson().containsKey('beanId'), isFalse);
      expect(anonymized.toJson().containsKey('sourceShotId'), isFalse);
      expect(anonymized.toJson().containsKey('notes'), isFalse);
    });
  });

  group('generateShareLink', () {
    test('returns flowlog deep link with base64 payload', () {
      final profile = SavedProfile(
        id: 'profile-share',
        name: 'Share me',
        createdAt: DateTime.utc(2026, 6, 29, 12),
        sourceShotId: 'shot-1',
        beanId: 'bean-secret',
        pressureSamples: const [
          ShotSample(elapsedMs: 1000, pressureBar: 8),
        ],
      );

      final link = generateShareLink(profile);

      expect(link, startsWith('flowlog://profile/'));
      final hash = link.substring('flowlog://profile/'.length);
      expect(hash, isNotEmpty);

      final decoded = utf8.decode(base64Url.decode(hash));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      expect(json['id'], 'profile-share');
      expect(json['pressureSamples'], isNotEmpty);
      expect(json.containsKey('beanId'), isFalse);
      expect(json.containsKey('sourceShotId'), isFalse);
      expect(json.containsKey('notes'), isFalse);
    });
  });

  group('ShareProfileButton', () {
    testWidgets('dialog does not overflow with large profile link', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final profile = SavedProfile.fromShot(shot, id: shot.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showShareProfileDialog(context, profile),
                child: const Text('Share'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_profile_dialog')), findsOneWidget);
      expect(find.byKey(const Key('share_profile_link')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens dialog with generated link', (tester) async {
      final profile = SavedProfile(
        id: 'profile-ui',
        name: 'UI profile',
        createdAt: DateTime.utc(2026, 6, 29, 12),
        pressureSamples: const [
          ShotSample(elapsedMs: 0, pressureBar: 1),
        ],
      );
      final link = generateShareLink(profile);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareProfileButton(profile: profile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('share_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_profile_dialog')), findsOneWidget);
      expect(find.byKey(const Key('share_profile_link')), findsOneWidget);
      expect(find.text(link), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('copy link shows snackbar feedback', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(shot: shot),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('share_profile_button')));
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();

      expect(find.text('Profile link copied'), findsOneWidget);
      expect(find.byKey(const Key('share_profile_snackbar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ShotDetailScreen integration', () {
    testWidgets('app bar includes share profile action', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(shot: shot),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_profile_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('share_profile_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_profile_dialog')), findsOneWidget);
      expect(
        find.textContaining('flowlog://profile/'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final file = File(_fixturePath(relativePath));
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Shot.fromJson(json);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
    '../../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}