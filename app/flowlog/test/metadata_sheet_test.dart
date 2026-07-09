import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShotMetadata', () {
    test('fromShot copies metadata fields', () {
      final shot = _loadFixtureShot();

      final metadata = ShotMetadata.fromShot(shot);

      expect(metadata.doseG, shot.doseG);
      expect(metadata.yieldG, shot.yieldG);
      expect(metadata.grindSetting, shot.grindSetting);
      expect(metadata.beanId, shot.beanId);
      expect(metadata.waterTempC, shot.waterTempC);
      expect(metadata.notes, shot.notes);
      expect(metadata.tasteScore, shot.tasteScore);
      expect(metadata.flavourTags, shot.flavourTags);
    });

    test('applyTo updates shot metadata fields', () {
      final shot = _loadFixtureShot();
      const metadata = ShotMetadata(
        doseG: 19,
        yieldG: 38,
        grindSetting: 13,
        beanId: 'bean-test',
        waterTempC: 94,
        notes: 'Updated notes',
        tasteScore: 8,
        flavourTags: ['bright', 'body'],
      );

      final updated = metadata.applyTo(shot);

      expect(updated.id, shot.id);
      expect(updated.startedAt, shot.startedAt);
      expect(updated.samples, shot.samples);
      expect(updated.doseG, 19);
      expect(updated.yieldG, 38);
      expect(updated.grindSetting, 13);
      expect(updated.beanId, 'bean-test');
      expect(updated.waterTempC, 94);
      expect(updated.notes, 'Updated notes');
      expect(updated.tasteScore, 8);
      expect(updated.flavourTags, ['bright', 'body']);
    });
  });

  group('MetadataSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      ShotMetadata? initial,
      ValueChanged<ShotMetadata?>? onResult,
    }) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      final result = await showMetadataSheet(
                        context,
                        initial: initial,
                      );
                      onResult?.call(result);
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('shows metadata form fields', (tester) async {
      await pumpSheet(tester);

      expect(find.text('Shot metadata'), findsOneWidget);
      expect(find.textContaining('Dose:'), findsOneWidget);
      expect(find.text('Yield (g)'), findsOneWidget);
      expect(find.textContaining('Grind:'), findsOneWidget);
      expect(find.text('Temp (°C)'), findsOneWidget);
      expect(find.byKey(const Key('metadata_dose_slider')), findsOneWidget);
      expect(find.byKey(const Key('metadata_grind_slider')), findsOneWidget);
      expect(find.byKey(const Key('metadata_grind_decrement')), findsOneWidget);
      expect(find.byKey(const Key('metadata_grind_increment')), findsOneWidget);
      expect(
        find.byKey(const Key('metadata_coffeejack_rewind_slider')),
        findsOneWidget,
      );
      expect(find.text('Bean'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Taste'), findsOneWidget);
      expect(find.text('Flavour tags'), findsOneWidget);
      expect(find.byKey(const Key('metadata_taste_slider')), findsOneWidget);
      expect(find.byKey(const Key('metadata_save')), findsOneWidget);
    });

    testWidgets('grind steppers adjust in 0.1 steps', (tester) async {
      await pumpSheet(tester);

      final starting = snapGrindSetting(kDefaultBrewGrindSetting);
      expect(find.text('Grind: ${formatGrindSetting(starting)}'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('metadata_grind_increment')));
      expect(
        find.text('Grind: ${formatGrindSetting(starting + kBrewGrindStep)}'),
        findsOneWidget,
      );

      await tapVisible(tester, find.byKey(const Key('metadata_grind_decrement')));
      expect(find.text('Grind: ${formatGrindSetting(starting)}'), findsOneWidget);
    });

    testWidgets('shows selectable flavour tag chips', (tester) async {
      await pumpSheet(tester);

      for (final tag in kFlavourTagOptions) {
        expect(find.text(tag), findsOneWidget);
      }
    });

    testWidgets('prefills fields from initial metadata', (tester) async {
      final shot = _loadFixtureShot();
      final initial = ShotMetadata.fromShot(shot);

      await pumpSheet(tester, initial: initial);

      expect(find.textContaining('Dose: 18.0 g'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('metadata_yield'))).controller?.text,
        '36',
      );
      expect(find.textContaining('Grind: 14.0'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('metadata_temp'))).controller?.text,
        '93',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('metadata_bean'))).controller?.text,
        'bean-house-blend',
      );
      expect(
        tester.widget<TextField>(find.byKey(const Key('metadata_notes'))).controller?.text,
        shot.notes,
      );
      expect(find.text('7'), findsOneWidget);

      final chocolateChip = tester.widget<FilterChip>(
        find.byKey(const Key('metadata_flavour_chocolate')),
      );
      final nuttyChip = tester.widget<FilterChip>(
        find.byKey(const Key('metadata_flavour_nutty')),
      );
      expect(chocolateChip.selected, isTrue);
      expect(nuttyChip.selected, isTrue);
    });

    testWidgets('includes funky preset flavour tag', (tester) async {
      await pumpSheet(tester);

      expect(find.byKey(const Key('metadata_flavour_funky')), findsOneWidget);
    });

    testWidgets('adds custom flavour tag via input row', (tester) async {
      await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const Key('metadata_custom_flavour_input')),
        'Jammy',
      );
      await tapVisible(tester, find.byKey(const Key('metadata_add_flavour_tag')));

      final jammyChip = tester.widget<FilterChip>(
        find.byKey(const Key('metadata_flavour_jammy')),
      );
      expect(jammyChip.selected, isTrue);
    });

    testWidgets('toggles flavour tag selection', (tester) async {
      await pumpSheet(tester);

      await tapVisible(tester, find.byKey(const Key('metadata_flavour_chocolate')));

      var chocolateChip = tester.widget<FilterChip>(
        find.byKey(const Key('metadata_flavour_chocolate')),
      );
      expect(chocolateChip.selected, isTrue);

      await tapVisible(tester, find.byKey(const Key('metadata_flavour_chocolate')));

      chocolateChip = tester.widget<FilterChip>(
        find.byKey(const Key('metadata_flavour_chocolate')),
      );
      expect(chocolateChip.selected, isFalse);
    });

    testWidgets('updates taste score via slider', (tester) async {
      await pumpSheet(tester);

      await tester.drag(
        find.byKey(const Key('metadata_taste_slider')),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      final valueText = tester.widget<Text>(
        find.byKey(const Key('metadata_taste_value')),
      );
      final score = int.parse(valueText.data!);
      expect(score, greaterThan(5));
      expect(score, lessThanOrEqualTo(10));
    });

    testWidgets('save returns ShotMetadata matching entered values', (tester) async {
      ShotMetadata? saved;

      await pumpSheet(
        tester,
        onResult: (value) => saved = value,
      );

      await tester.drag(
        find.byKey(const Key('metadata_dose_slider')),
        const Offset(40, 0),
      );
      await tester.drag(
        find.byKey(const Key('metadata_grind_slider')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('metadata_yield')), '37');
      await tester.enterText(find.byKey(const Key('metadata_temp')), '92');
      await tester.enterText(find.byKey(const Key('metadata_bean')), 'bean-house-blend');
      await tester.enterText(
        find.byKey(const Key('metadata_notes')),
        'Minimal fixture shot for tests and mock replay.',
      );
      await tester.tap(find.text('Flavour tags'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key('metadata_flavour_chocolate')));
      await tapVisible(tester, find.byKey(const Key('metadata_flavour_nutty')));

      await tapVisible(tester, find.byKey(const Key('metadata_save')));

      expect(saved, isNotNull);
      final metadata = saved!;
      expect(metadata.doseG, greaterThan(kDefaultBrewDoseG));
      expect(metadata.yieldG, 37);
      expect(metadata.grindSetting, greaterThan(kDefaultBrewGrindSetting));
      expect(metadata.beanId, 'bean-house-blend');
      expect(metadata.waterTempC, 92);
      expect(metadata.notes, 'Minimal fixture shot for tests and mock replay.');
      expect(metadata.tasteScore, 5);
      expect(metadata.flavourTags, ['chocolate', 'nutty']);
      expect(metadata.flavourIntensities, {'chocolate': 5, 'nutty': 5});
    });

    testWidgets('shows intensity sliders for selected flavour tags', (
      tester,
    ) async {
      await pumpSheet(tester);

      await tapVisible(tester, find.byKey(const Key('metadata_flavour_chocolate')));
      await tapVisible(tester, find.byKey(const Key('metadata_flavour_nutty')));

      expect(
        find.byKey(const Key('metadata_flavour_intensity_chocolate')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('metadata_flavour_intensity_nutty')),
        findsOneWidget,
      );
    });

    testWidgets('fixture metadata round-trips through sheet', (tester) async {
      final shot = _loadFixtureShot();
      final initial = ShotMetadata.fromShot(shot);
      ShotMetadata? saved;

      await pumpSheet(
        tester,
        initial: initial,
        onResult: (value) => saved = value,
      );

      await tapVisible(tester, find.byKey(const Key('metadata_save')));

      final expected = initial.copyWith(
        flavourIntensities: const {'chocolate': 5, 'nutty': 5},
        coffeejackRewindTurns: kDefaultCoffeejackRewindTurns,
        coffeejackPreinfusionTurns: kDefaultCoffeejackPreinfusionTurns,
      );
      expect(saved, expected);
      expect(
        saved!.applyTo(shot),
        shot.copyWith(
          flavourIntensities: const {'chocolate': 5, 'nutty': 5},
          coffeejackRewindTurns: kDefaultCoffeejackRewindTurns,
          coffeejackPreinfusionTurns: kDefaultCoffeejackPreinfusionTurns,
        ),
      );
    });
  });
}

Shot _loadFixtureShot() {
  final file = File(
    '${Directory.current.path}/../../fixtures/shots/minimal_shot.json',
  );
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Shot.fromJson(json);
}