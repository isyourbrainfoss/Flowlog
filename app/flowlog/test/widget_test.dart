import 'package:flowlog/main.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helpers.dart';
import 'shell_test_helpers.dart';

void main() {
  testWidgets('Flowlog shell shows Live tab by default', (tester) async {
    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsWidgets);
    expect(find.text('Session: idle'), findsOneWidget);
    expect(find.byKey(const Key('live_brew')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('Shell navigates to all four tabs', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpFlowlogApp(tester);

    final destinations = <(AppTab tab, Finder bodyFinder)>[
      (AppTab.live, find.text('Session: idle')),
      (AppTab.history, find.byKey(const Key('history_filter_bean'))),
      (AppTab.library, find.byKey(const Key('library_tab_beans'))),
      (AppTab.more, find.byKey(const Key('more_brew_defaults_tile'))),
    ];

    for (final (tab, bodyFinder) in destinations) {
      await selectShellTab(tester, tab);
      await pumpUntilFound(tester, bodyFinder);
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

    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
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
    expect(find.byKey(const Key('live_brew')), findsOneWidget);
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
    expect(find.byKey(const Key('live_brew')), findsOneWidget);
  });

  testWidgets('resize to mobile preserves live session samples', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    final registry = FlowlogShortcutsScope.of(
      tester.element(find.byKey(const Key('live_brew'))),
    ).registry;
    await tester.runAsync(() async {
      await registry.startDemoShot?.call();
      await tester.pump();
    });
    await tester.pump(const Duration(milliseconds: 500));

    final samplesFinder = find.textContaining('samples');
    expect(samplesFinder, findsOneWidget);
    final samplesBefore = tester.widget<Text>(samplesFinder).data!;

    final countBefore = int.parse(samplesBefore.split(' ').first);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();

    await tester.ensureVisible(find.textContaining('samples'));
    final samplesAfter =
        tester.widget<Text>(find.textContaining('samples')).data!;
    final countAfter = int.parse(samplesAfter.split(' ').first);
    expect(countAfter, greaterThanOrEqualTo(countBefore));
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
      '/library': 'Library',
      '/more': 'Sensors',
    };

    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final entry in routeBodies.entries) {
      navigator.pushNamed(entry.key);
      await pumpForAsync(tester, frames: 5);
      expect(find.text(entry.value), findsWidgets);
      navigator.pop();
      await pumpForAsync(tester);
    }
  });
}