import 'package:flowlog/screens/live/live_idle_layout.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'routes pushed on the root navigator still reach the shell scopes',
    (tester) async {
      final switched = <AppTab>[];
      final registry = FlowlogShortcutRegistry();

      // Mirrors main.dart: the shell (and its scopes) is MaterialApp.home,
      // so routes pushed from More sit *above* it in the element tree.
      await tester.pumpWidget(
        MaterialApp(
          home: FlowlogShellScope(
            switchTab: switched.add,
            child: FlowlogShortcutsScope(
              currentTab: AppTab.more,
              registry: registry,
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (routeContext) => Scaffold(
                        body: TextButton(
                          onPressed: () {
                            FlowlogShellScope.maybeOf(
                              routeContext,
                            )?.switchTab(AppTab.library);
                          },
                          child: Text(
                            FlowlogShortcutsScope.maybeOf(routeContext) == null
                                ? 'no shortcuts'
                                : 'has shortcuts',
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('has shortcuts'), findsOneWidget);

      await tester.tap(find.text('has shortcuts'));
      expect(switched, [AppTab.library]);
    },
  );

  testWidgets('scope fallback is cleared when the shell unmounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      FlowlogShellScope(switchTab: (_) {}, child: const SizedBox()),
    );
    await tester.pumpWidget(const SizedBox());

    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(FlowlogShellScope.maybeOf(context), isNull);
  });

  testWidgets('pinned Live layout gives spare height to the chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveIdleLayout(
            pinChart: true,
            useCompactLayout: false,
            // Banner + chart taller than the old 3/5 share (360 px).
            chartSection: SingleChildScrollView(
              child: SizedBox(key: Key('chart'), height: 420),
            ),
            controlsSection: SizedBox(key: Key('controls'), height: 60),
          ),
        ),
      ),
    );

    final chartViewport = tester.getSize(
      find
          .ancestor(
            of: find.byKey(const Key('chart')),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    // Whole chart is visible: only the controls' real height is taken.
    expect(chartViewport.height, greaterThanOrEqualTo(420));
    expect(find.byKey(const Key('controls')), findsOneWidget);
  });
}
