import 'package:flowlog/main.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helpers.dart';

/// Pumps [FlowlogApp] and waits for shell startup I/O to finish.
Future<void> pumpFlowlogApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const FlowlogApp(autoReconnectSensors: false),
  );
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump();
}

/// Switches the Flowlog shell to [tab] (reliable in widget tests).
Future<void> selectShellTab(WidgetTester tester, AppTab tab) async {
  final scopeElement = tester.element(find.byType(FlowlogShellScope));
  FlowlogShellScope.maybeOf(scopeElement)?.switchTab(tab);
  await tester.pump();
}

/// Switches the Flowlog shell to the History tab in widget tests.
Future<void> selectHistoryTab(WidgetTester tester) async {
  await selectShellTab(tester, AppTab.history);
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await pumpUntilFound(tester, find.byKey(const Key('history_filter_bean')));
}