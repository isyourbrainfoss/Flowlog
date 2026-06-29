import 'package:flowlog/main.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowlogTheme', () {
    test('coffeeDark uses warm coffee palette', () {
      final theme = FlowlogTheme.coffeeDark;
      final scheme = theme.colorScheme;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, FlowlogColors.crema);
      expect(scheme.secondary, FlowlogColors.espresso);
      expect(theme.scaffoldBackgroundColor, FlowlogColors.backgroundDark);
      expect(scheme.onSurface, FlowlogColors.onBackgroundDark);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(FlowlogColors.cardRadius));
    });

    test('cafeLight uses warm cream palette', () {
      final theme = FlowlogTheme.cafeLight;
      final scheme = theme.colorScheme;

      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, FlowlogColors.espresso);
      expect(scheme.secondary, FlowlogColors.crema);
      expect(theme.scaffoldBackgroundColor, FlowlogColors.backgroundLight);
      expect(scheme.onSurface, FlowlogColors.onBackgroundLight);
    });

    test('both themes share accent tokens', () {
      expect(FlowlogColors.crema, const Color(0xFFC4A574));
      expect(FlowlogColors.espresso, const Color(0xFF6F4E37));
      expect(FlowlogColors.cardRadius, 12);
      expect(FlowlogColors.cardElevation, 1);
    });
  });

  group('FlowlogThemeController', () {
    test('defaults to dark mode', () {
      final controller = FlowlogThemeController();
      addTearDown(controller.dispose);

      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDark, isTrue);
    });

    test('setThemeMode notifies listeners', () {
      final controller = FlowlogThemeController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setThemeMode(ThemeMode.light);

      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isDark, isFalse);
      expect(notifications, 1);

      controller.setThemeMode(ThemeMode.light);
      expect(notifications, 1);
    });
  });

  testWidgets('Appearance toggle switches theme mode', (tester) async {
    final controller = FlowlogThemeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(FlowlogApp(themeController: controller));
    await tester.pumpAndSettle();

    expect(controller.isDark, isTrue);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Coffee dark'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.isDark, isFalse);
    expect(find.text('Café light'), findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.light);
  });
}