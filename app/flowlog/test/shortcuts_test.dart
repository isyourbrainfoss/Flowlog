import 'package:flowlog/main.dart';
import 'package:flowlog/screens/more/export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> selectHistoryTab(WidgetTester tester) async {
    final historyTooltip = find.byTooltip('Shot history');
    if (historyTooltip.evaluate().isNotEmpty) {
      await tester.tap(historyTooltip);
    } else {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.history),
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> sendShortcut(
    WidgetTester tester, {
    required LogicalKeyboardKey key,
    bool control = false,
  }) async {
    if (control) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    if (control) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    }
  }

  testWidgets('Space on Live tab toggles start and stop', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    expect(find.text('Session: idle'), findsOneWidget);

    await tester.runAsync(() async {
      await sendShortcut(tester, key: LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
    });

    expect(find.text('Stop brew'), findsOneWidget);

    await tester.runAsync(() async {
      await sendShortcut(tester, key: LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
    });

    expect(find.text('Session: stopped'), findsOneWidget);
    expect(find.text('Start brew'), findsOneWidget);
  });

  testWidgets('Space on non-Live tab does not start a shot', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    await selectHistoryTab(tester);

    await tester.runAsync(() async {
      await sendShortcut(tester, key: LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
    });

    expect(find.text('Session: idle'), findsNothing);
    expect(find.byKey(const Key('history_filter_bean')), findsOneWidget);
  });

  testWidgets('Ctrl+E opens export screen from Live tab', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    await sendShortcut(
      tester,
      key: LogicalKeyboardKey.keyE,
      control: true,
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Export shots'), findsOneWidget);
    expect(find.byType(ExportScreen), findsOneWidget);
  });

  testWidgets('Ctrl+E opens export screen from History tab', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    await selectHistoryTab(tester);

    await sendShortcut(
      tester,
      key: LogicalKeyboardKey.keyE,
      control: true,
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Export shots'), findsOneWidget);
    expect(find.byType(ExportScreen), findsOneWidget);
  });
}