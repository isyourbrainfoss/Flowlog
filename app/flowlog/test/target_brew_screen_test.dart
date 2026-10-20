import 'dart:io';

import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/screens/more/target_brew_screen.dart';
import 'package:flowlog/settings/target_brew_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TargetBrewScreen', () {
    late Directory tempDir;
    late FlowlogDatabase database;
    late ProfileRepository profileRepository;
    late TargetBrewController appController;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('flowlog_target_screen');
      database = FlowlogDatabase.inMemory();
      profileRepository = ProfileRepository(database);
      appController = TargetBrewController(
        settingsStore: TargetBrewSettingsStore(
          settingsPath: '${tempDir.path}/target_brew.json',
        ),
      );
    });

    tearDown(() async {
      appController.dispose();
      await database.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets(
      'uses the app-level TargetBrewScope controller and reflects changes',
      (tester) async {
        final profile = SavedProfile(
          id: 'profile-9bar',
          name: 'Nine bar hold',
          createdAt: DateTime.utc(2026, 10, 1),
          pressureSamples: const [
            ShotSample(elapsedMs: 0, pressureBar: 2),
            ShotSample(elapsedMs: 8000, pressureBar: 9),
            ShotSample(elapsedMs: 30000, pressureBar: 9),
          ],
        );
        await tester.runAsync(() async {
          await profileRepository.insertProfile(profile);
          await appController.setProfile(profile);
        });

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                TargetBrewScope(controller: appController, child: child!),
            home: TargetBrewScreen(profileRepository: profileRepository),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }

        expect(find.text('Nine bar hold'), findsOneWidget);
        expect(find.byKey(const Key('target_brew_clear')), findsOneWidget);

        await tester.tap(find.byKey(const Key('target_brew_clear')));
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }

        // The shared (Live) controller is cleared...
        expect(appController.hasTarget, isFalse);
        // ...and this screen shows it right away (used to stay stale).
        expect(find.text('None set'), findsOneWidget);
        expect(find.text('Nine bar hold'), findsNothing);
        expect(find.byKey(const Key('target_brew_clear')), findsNothing);
      },
    );
  });
}
