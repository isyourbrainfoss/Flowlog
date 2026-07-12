import 'package:flowlog/main.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/shell/top_bar.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

const String _testBeanName = 'Test Blend';

void main() {
  Future<void> pumpTopBar(
    WidgetTester tester, {
    String beanName = _testBeanName,
    Future<List<Bean>> Function()? loadBeans,
    void Function(String name, {String? beanId})? onActiveBeanChanged,
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
            loadBeans: loadBeans,
            onActiveBeanChanged: onActiveBeanChanged,
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

      expect(find.text(_testBeanName), findsOneWidget);
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
        _testBeanName,
      );
    });

    testWidgets('saves edited bean name', (tester) async {
      String? updatedName;
      String? updatedBeanId;

      await pumpTopBar(
        tester,
        onActiveBeanChanged: (name, {beanId}) {
          updatedName = name;
          updatedBeanId = beanId;
        },
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
      expect(updatedBeanId, isNull);
    });

    testWidgets('shows autocomplete options from bean loader', (tester) async {
      const beans = [
        Bean(id: 'bean-1', name: 'Ethiopia Yirgacheffe'),
        Bean(id: 'bean-2', name: 'Colombia Huila'),
      ];

      await pumpTopBar(
        tester,
        loadBeans: () async => beans,
      );

      await tester.tap(find.byKey(const Key('top_bar_bean_name')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('top_bar_bean_edit_field')),
        'Eth',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ethiopia Yirgacheffe'), findsWidgets);
      expect(find.text('Colombia Huila'), findsNothing);
    });

    testWidgets('bean field clear button empties the text field', (tester) async {
      await pumpTopBar(tester);

      await tester.tap(find.byKey(const Key('top_bar_bean_name')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('top_bar_bean_clear')), findsOneWidget);

      await tester.tap(find.byKey(const Key('top_bar_bean_clear')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('top_bar_bean_edit_field')))
            .controller
            ?.text,
        isEmpty,
      );
      expect(find.byKey(const Key('top_bar_bean_clear')), findsNothing);
    });

    testWidgets('returns bean id when selecting autocomplete option',
        (tester) async {
      const beans = [
        Bean(id: 'bean-eth', name: 'Ethiopia Yirgacheffe'),
        Bean(id: 'bean-col', name: 'Colombia Huila'),
      ];
      String? updatedName;
      String? updatedBeanId;

      await pumpTopBar(
        tester,
        loadBeans: () async => beans,
        onActiveBeanChanged: (name, {beanId}) {
          updatedName = name;
          updatedBeanId = beanId;
        },
      );

      await tester.tap(find.byKey(const Key('top_bar_bean_name')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('top_bar_bean_edit_field')),
        'Eth',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ethiopia Yirgacheffe').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('top_bar_bean_save')));
      await tester.pumpAndSettle();

      expect(updatedName, 'Ethiopia Yirgacheffe');
      expect(updatedBeanId, 'bean-eth');
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
                appBar: const FlowlogTopBar(beanName: _testBeanName),
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
    testWidgets('shell shows top bar bean picker (no default bean)', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const FlowlogApp(autoReconnectSensors: false),
      );
      await tester.pump();

      expect(find.byType(FlowlogTopBar), findsOneWidget);
      expect(find.text('Select bean'), findsOneWidget);
      expect(find.byKey(const Key('top_bar_prs_status')), findsOneWidget);
      expect(find.byKey(const Key('top_bar_scale_status')), findsOneWidget);
    });
  });
}