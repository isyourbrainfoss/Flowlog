import 'package:flowlog/main.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
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
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    final destinations = [
      (Icons.history, 'No saved shots yet'),
      (Icons.local_cafe_outlined, 'Beans & profiles'),
      (Icons.tune, 'Sensors'),
      (Icons.play_circle_outline, 'Session: idle'),
    ];

    for (final (icon, body) in destinations) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(find.text(body), findsOneWidget);
    }
  });

  testWidgets('Wide layout uses extended sidebar rail', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FlowlogShell()),
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
      const MaterialApp(home: FlowlogShell()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Very small window does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FlowlogShell()),
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
      const MaterialApp(home: FlowlogShell()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Session: idle'), findsOneWidget);
    expect(find.byKey(const Key('live_start')), findsOneWidget);
  });

  testWidgets('Short height uses bottom bar even when wide', (tester) async {
    tester.view.physicalSize = const Size(800, 280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FlowlogShell()),
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
      '/library': 'Beans & profiles',
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