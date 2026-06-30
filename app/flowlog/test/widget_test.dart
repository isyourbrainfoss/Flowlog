import 'package:flowlog/main.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flowlog shell shows Live tab by default', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsWidgets);
    expect(find.text('Session: idle'), findsOneWidget);
    expect(find.byKey(const Key('live_start')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('Shell navigates to all four tabs', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    final destinations = <(String tooltip, Finder bodyFinder)>[
      ('Live shot recording', find.text('Session: idle')),
      ('Shot history', find.byKey(const Key('history_filter_bean'))),
      ('Bean library', find.text('Beans')),
      ('More settings', find.text('Sensors')),
    ];

    for (final (tooltip, bodyFinder) in destinations) {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(bodyFinder, findsOneWidget);
    }
  });

  testWidgets('Wide layout uses extended sidebar rail', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SensorHubScope(
          hub: SensorHub(),
          child: const FlowlogShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('History'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Narrow width uses bottom navigation bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SensorHubScope(
          hub: SensorHub(),
          child: const FlowlogShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Narrow layout keeps live chart visible', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    expect(find.byType(DualCurveChart), findsOneWidget);
    final chart = tester.widget<DualCurveChart>(find.byType(DualCurveChart));
    expect(chart.height, greaterThanOrEqualTo(140));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Very small window does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SensorHubScope(
          hub: SensorHub(),
          child: const FlowlogShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Session: idle'), findsOneWidget);
    expect(find.byKey(const Key('live_start')), findsOneWidget);
  });

  testWidgets('Ultra-short window hides app bar and does not overflow', (
    tester,
  ) async {
    // Matches narrow phone-ish width with almost no vertical space (body ~54px).
    tester.view.physicalSize = const Size(303, 130);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SensorHubScope(
          hub: SensorHub(),
          child: const FlowlogShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Session: idle'), findsOneWidget);
    expect(find.byKey(const Key('live_start')), findsOneWidget);
  });

  testWidgets('resize to mobile preserves live session samples', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('live_try_demo')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final samplesFinder = find.textContaining('samples');
    expect(samplesFinder, findsOneWidget);
    final samplesBefore = tester.widget<Text>(samplesFinder).data!;

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();

    expect(find.text(samplesBefore), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phone landscape keeps bottom navigation bar', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SensorHubScope(
          hub: SensorHub(),
          child: const FlowlogShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Short height uses bottom bar even when wide', (tester) async {
    tester.view.physicalSize = const Size(800, 280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SensorHubScope(
          hub: SensorHub(),
          child: const FlowlogShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Named routes resolve to placeholder screens', (tester) async {
    const routeBodies = {
      '/live': 'Live',
      '/history': 'History',
      '/library': 'No beans yet',
      '/more': 'Sensors',
    };

    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final entry in routeBodies.entries) {
      navigator.pushNamed(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });
}