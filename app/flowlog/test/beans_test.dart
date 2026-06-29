import 'package:flowlog/screens/library/beans.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeansScreen', () {
    late FlowlogDatabase db;
    late BeanRepository beanRepository;
    late ShotRepository shotRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      beanRepository = BeanRepository(db);
      shotRepository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows empty state when no beans exist', (tester) async {
      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      expect(find.text('No beans yet'), findsOneWidget);
      expect(find.byType(BeanCard), findsNothing);
    });

    testWidgets('creates bean from add dialog', (tester) async {
      await _pumpBeansScreen(
        tester,
        beanRepository: beanRepository,
        beanIdGenerator: () => 'bean-test',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_editor_add')), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'House Blend',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Origin'),
        'Brazil',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Roast'),
        'medium',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Stock (g)'),
        '500',
      );

      await tester.tap(find.byKey(const Key('bean_editor_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_card_bean-test')), findsOneWidget);
      expect(find.text('House Blend'), findsOneWidget);
      expect(find.text('Brazil · medium'), findsOneWidget);
      expect(find.text('0 shots'), findsOneWidget);

      final saved = await beanRepository.getBeanById('bean-test');
      expect(saved, isNotNull);
      expect(saved!.name, 'House Blend');
      expect(saved.stockG, 500);
    });

    testWidgets('shows linked shot count on bean card', (tester) async {
      const bean = Bean(id: 'bean-linked', name: 'Linked Bean');
      await beanRepository.upsertBean(bean);
      await shotRepository.insertShot(
        Shot(
          id: 'shot-1',
          startedAt: DateTime.utc(2026, 6, 29, 10),
          beanId: bean.id,
        ),
      );
      await shotRepository.insertShot(
        Shot(
          id: 'shot-2',
          startedAt: DateTime.utc(2026, 6, 29, 11),
          beanId: bean.id,
        ),
      );

      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_shot_count_bean-linked')), findsOneWidget);
      expect(find.text('2 shots'), findsOneWidget);
    });

    testWidgets('updates stock inline', (tester) async {
      const bean = Bean(
        id: 'bean-stock',
        name: 'Stock Bean',
        stockG: 300,
      );
      await beanRepository.upsertBean(bean);

      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      final stockField = find.byKey(const Key('bean_stock_bean-stock'));
      await tester.enterText(stockField, '250');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final updated = await beanRepository.getBeanById(bean.id);
      expect(updated!.stockG, 250);
    });

    testWidgets('deletes bean from card action', (tester) async {
      const bean = Bean(id: 'bean-delete', name: 'Delete Me');
      await beanRepository.upsertBean(bean);

      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bean_delete_bean-delete')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_card_bean-delete')), findsNothing);
      expect(await beanRepository.getBeanById(bean.id), isNull);
    });
  });
}

Future<void> _pumpBeansScreen(
  WidgetTester tester, {
  required BeanRepository beanRepository,
  BeanIdGenerator? beanIdGenerator,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BeansScreen(
        beanRepository: beanRepository,
        beanIdGenerator: beanIdGenerator ?? generateBeanId,
      ),
    ),
  );
}