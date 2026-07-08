import 'package:flowlog/screens/library/beans.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        find.byKey(const Key('bean_editor_variety')),
        'Yellow Catuai',
      );
      await tester.ensureVisible(
        find.byKey(const Key('bean_process_washed')),
      );
      await tester.tap(find.byKey(const Key('bean_process_washed')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('bean_stock_preset_250')),
      );
      await tester.tap(find.byKey(const Key('bean_stock_preset_250')));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('bean_editor_save')));
      await tester.tap(find.byKey(const Key('bean_editor_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_card_bean-test')), findsOneWidget);
      expect(find.text('House Blend'), findsOneWidget);
      expect(
        find.textContaining('Brazil · Yellow Catuai · Washed · Medium'),
        findsOneWidget,
      );
      expect(find.text('0 shots'), findsOneWidget);

      final saved = await beanRepository.getBeanById('bean-test');
      expect(saved, isNotNull);
      expect(saved!.name, 'House Blend');
      expect(saved.stockG, 250);
      expect(saved.roastLevel, 'Medium');
      expect(saved.process, 'Washed');
      expect(saved.variety, 'Yellow Catuai');
    });

    testWidgets('creates bean with custom bag size', (tester) async {
      await _pumpBeansScreen(
        tester,
        beanRepository: beanRepository,
        beanIdGenerator: () => 'bean-custom-bag',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Custom Bag',
      );
      await tester.ensureVisible(
        find.byKey(const Key('bean_stock_custom_field')),
      );
      await tester.enterText(
        find.byKey(const Key('bean_stock_custom_field')),
        '340',
      );
      await tester.ensureVisible(find.byKey(const Key('bean_editor_save')));
      await tester.tap(find.byKey(const Key('bean_editor_save')));
      await tester.pumpAndSettle();

      final saved = await beanRepository.getBeanById('bean-custom-bag');
      expect(saved?.stockG, 340);
      expect(find.byKey(const Key('bean_card_bean-custom-bag')), findsOneWidget);
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

    testWidgets('bean editor does not dismiss on barrier tap', (tester) async {
      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_editor_add')), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_editor_add')), findsOneWidget);
    });

    testWidgets('bean editor confirms discard when dirty on back', (tester) async {
      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Dirty Bean',
      );
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard unsaved bean changes?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_editor_add')), findsNothing);
      expect(find.text('No beans yet'), findsOneWidget);
    });

    testWidgets('copies AI prompt from bean editor', (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText =
                (methodCall.arguments as Map<Object?, Object?>)['text']
                    as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('bean_ai_copy_prompt')));
      await tester.tap(find.byKey(const Key('bean_ai_copy_prompt')));
      await tester.pumpAndSettle();

      expect(clipboardText, buildBeanAiPrompt());
      expect(
        find.byKey(const Key('bean_ai_prompt_copied_snackbar')),
        findsOneWidget,
      );
    });

    testWidgets('imports AI response from clipboard into bean editor',
        (tester) async {
      const clipboardJson = '''
```json
{
  "name": "Guji Natural",
  "brand": "Square Mile",
  "origin": "Ethiopia",
  "variety": "Heirloom",
  "process": "Natural",
  "roastLevel": "Light",
  "roastDate": "2026-02-10",
  "stockG": 250,
  "notes": "Blueberry"
}
```
''';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': clipboardJson};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpBeansScreen(
        tester,
        beanRepository: beanRepository,
        beanIdGenerator: () => 'bean-ai-import',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('bean_ai_import_clipboard')),
      );
      await tester.tap(find.byKey(const Key('bean_ai_import_clipboard')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_ai_import_dialog')), findsNothing);
      expect(
        find.byKey(const Key('bean_ai_imported_snackbar')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Name'),
        findsOneWidget,
      );
      expect(
        find
            .widgetWithText(TextFormField, 'Name')
            .evaluate()
            .single
            .widget,
        isA<TextFormField>().having(
          (field) => field.controller?.text,
          'controller text',
          'Guji Natural',
        ),
      );
      expect(
        find.byKey(const Key('bean_editor_brand')).evaluate().single.widget,
        isA<TextFormField>().having(
          (field) => field.controller?.text,
          'controller text',
          'Square Mile',
        ),
      );
      expect(find.text('Roast: Light'), findsOneWidget);
      expect(find.text('2026-02-10'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('bean_editor_save')));
      await tester.tap(find.byKey(const Key('bean_editor_save')));
      await tester.pumpAndSettle();

      final saved = await beanRepository.getBeanById('bean-ai-import');
      expect(saved?.name, 'Guji Natural');
      expect(saved?.brand, 'Square Mile');
      expect(saved?.process, 'Natural');
      expect(saved?.roastLevel, 'Light');
      expect(saved?.stockG, 250);
      expect(saved?.notes, 'Blueberry');
    });

    testWidgets('opens import dialog when clipboard JSON is invalid',
        (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return {'text': 'not valid json'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _pumpBeansScreen(tester, beanRepository: beanRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beans_add_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bean_ai_import_clipboard')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bean_ai_import_dialog')), findsOneWidget);
      expect(
        find.byKey(const Key('bean_ai_import_field')),
        findsOneWidget,
      );
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