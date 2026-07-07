import 'package:flutter_test/flutter_test.dart';

/// Pumps a few frames so [FutureBuilder] and file I/O can finish without
/// waiting on spinners or live charts (which block [pumpAndSettle]).
Future<void> pumpForAsync(WidgetTester tester, {int frames = 3}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Waits until [finder] matches or [timeout] elapses.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

/// Pumps until [finder] no longer matches.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (finder.evaluate().isEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsNothing);
}