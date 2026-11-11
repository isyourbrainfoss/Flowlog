import 'dart:io';

import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/more/brew_defaults_screen.dart';
import 'package:flowlog/settings/auto_start_settings_store.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingBrewDefaultsStore extends BrewDefaultsSettingsStore {
  _CountingBrewDefaultsStore({required super.settingsPath});

  final saved = <BrewDefaultsSettings>[];
  var completed = 0;

  @override
  Future<void> save(BrewDefaultsSettings settings) async {
    saved.add(settings);
    await super.save(settings);
    completed++;
  }
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('flowlog_brew_defaults_screen');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  testWidgets('dragging the target-yield slider saves once, on release', (
    tester,
  ) async {
    final store = _CountingBrewDefaultsStore(
      settingsPath: '${dir.path}/brew_defaults.json',
    );
    final autoStart = AutoStartSettingsController(
      settingsStore: AutoStartSettingsStore(
        settingsPath: '${dir.path}/auto_start.json',
      ),
    );
    addTearDown(autoStart.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BrewDefaultsScreen(
          brewDefaultsStore: store,
          coffeejackSettingsStore: CoffeejackSettingsStore(
            settingsPath: '${dir.path}/coffeejack.json',
          ),
          autoStartController: autoStart,
        ),
      ),
    );
    final slider = find.byKey(const Key('brew_defaults_target_yield'));
    final loading = find.byType(CircularProgressIndicator);
    for (var i = 0; i < 50 && loading.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.scrollUntilVisible(
      slider,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final before = tester.widget<Slider>(slider).value;

    final gesture = await tester.startGesture(tester.getCenter(slider));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump();
    }
    expect(store.saved, isEmpty, reason: 'no disk write per drag tick');
    await gesture.up();
    await tester.pump();

    final after = tester.widget<Slider>(slider).value;
    expect(after, isNot(before));
    expect(store.saved, hasLength(1));
    expect(store.saved.single.targetYieldG, after);

    // Real file IO: let it run, flushing fake-zone microtasks between ticks.
    for (var i = 0; i < 100 && store.completed < 1; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    final reloaded = await tester.runAsync(() async {
      return BrewDefaultsSettingsStore(
        settingsPath: '${dir.path}/brew_defaults.json',
      ).load();
    });
    expect(reloaded!.targetYieldG, after);
  });
}
