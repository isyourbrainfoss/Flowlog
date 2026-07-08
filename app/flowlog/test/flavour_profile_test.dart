import 'package:flowlog/widgets/flavour_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlavourProfileSection', () {
    testWidgets('shows empty state when no taste or tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlavourProfileSection(
              tasteScore: null,
              flavourTags: [],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('flavour_profile_section')), findsOneWidget);
      expect(find.text('Flavour profile'), findsOneWidget);
      expect(find.textContaining('No flavour notes recorded yet'), findsOneWidget);
    });

    testWidgets('shows taste score and flavour tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FlavourProfileSection(
              tasteScore: 8,
              flavourTags: ['chocolate', 'nutty'],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('flavour_profile_taste_value')), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_tags')), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_tag_chocolate')), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_tag_nutty')), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_bars')), findsOneWidget);
    });
  });
}