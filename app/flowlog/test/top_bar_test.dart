import 'package:flowlog/main.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/shell/top_bar.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpTopBar(
    WidgetTester tester, {
    String beanName = kDefaultBeanName,
    ValueChanged<String>? onBeanNameChanged,
    ConnectionState pressensorState = ConnectionState.disconnected,
    ConnectionState scaleState = ConnectionState.disconnected,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? FlowlogTheme.coffeeDark,
        home: Scaffold(
          appBar: FlowlogTopBar(
            beanName: beanName,
            onBeanNameChanged: onBeanNameChanged,
            pressensorState: pressensorState,
            scaleState: scaleState,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('FlowlogTopBar', () {
    testWidgets('shows bean name and sensor status icons', (tester) async {
      await pumpTopBar(tester);

      expect(find.text(kDefaultBeanName), findsOneWidget);
      expect(find.byKey(const Key('top_bar_prs_status')), findsOneWidget);
      expect(find.byKey(const Key('top_bar_scale_status')), findsOneWidget);
      expect(find.byIcon(Icons.speed), findsOneWidget);
      expect(find.byIcon(Icons.scale), findsOneWidget);
    });

    testWidgets('uses Flowlog surface styling', (tester) async {
      await pumpTopBar(tester, theme: FlowlogTheme.coffeeDark);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FlowlogTopBar),
          matching: find.byType(Material),
        ),
      );
      expect(
        material.color,
        FlowlogTheme.coffeeDark.colorScheme.surface,
      );
    });

    testWidgets('opens bean name dialog on tap', (tester) async {
      await pumpTopBar(tester);

      await tester.tap(find.byKey(const Key('top_bar_bean_name')));
      await tester.pumpAndSettle();

      expect(find.text('Active bean'), findsOneWidget);
      expect(find.byKey(const Key('top_bar_bean_edit_field')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('top_bar_bean_edit_field')))
            .controller
            ?.text,
        kDefaultBeanName,
      );
    });

    testWidgets('saves edited bean name', (tester) async {
      String? updatedName;

      await pumpTopBar(
        tester,
        onBeanNameChanged: (name) => updatedName = name,
      );

      await tester.tap(find.byKey(const Key('top_bar_bean_name')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('top_bar_bean_edit_field')),
        'Ethiopia Yirgacheffe',
      );
      await tester.tap(find.byKey(const Key('top_bar_bean_save')));
      await tester.pumpAndSettle();

      expect(updatedName, 'Ethiopia Yirgacheffe');
    });

    testWidgets('sensor icons reflect mock connection states', (tester) async {
      await pumpTopBar(
        tester,
        pressensorState: ConnectionState.connected,
        scaleState: ConnectionState.disconnected,
      );

      final prsIcon = tester.widget<SensorConnectionIcon>(
        find.byKey(const Key('top_bar_prs_status')),
      );
      final scaleIcon = tester.widget<SensorConnectionIcon>(
        find.byKey(const Key('top_bar_scale_status')),
      );

      expect(prsIcon.state, ConnectionState.connected);
      expect(scaleIcon.state, ConnectionState.disconnected);
    });

    testWidgets('sensor icons open Sensors screen', (tester) async {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      await tester.pumpWidget(
        SensorHubScope(
          hub: hub,
          child: MaterialApp(
            home: FlowlogShellScope(
              switchTab: (_) {},
              child: Scaffold(
                appBar: const FlowlogTopBar(beanName: kDefaultBeanName),
                body: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('top_bar_prs_status')));
      await tester.pumpAndSettle();

      expect(find.text('Sensors'), findsWidgets);
      expect(find.byType(SensorsScreen), findsOneWidget);
    });
  });

  group('FlowlogShell top bar integration', () {
    testWidgets('shell shows top bar with default bean name', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const FlowlogApp(),
      );
      await tester.pump();

      expect(find.byType(FlowlogTopBar), findsOneWidget);
      expect(find.text(kDefaultBeanName), findsOneWidget);
      expect(find.byKey(const Key('top_bar_prs_status')), findsOneWidget);
      expect(find.byKey(const Key('top_bar_scale_status')), findsOneWidget);
    });
  });
}