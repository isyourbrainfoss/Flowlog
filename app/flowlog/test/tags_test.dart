import 'package:flowlog/screens/library/tags.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TagsScreen', () {
    late FlowlogDatabase db;
    late TagRepository tagRepository;
    late ShotRepository shotRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      tagRepository = TagRepository(db);
      shotRepository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows empty state when no tags exist', (tester) async {
      await _pumpTagsScreen(tester, tagRepository: tagRepository);
      await tester.pumpAndSettle();

      expect(find.text('No tags yet'), findsOneWidget);
      expect(find.byKey(const Key('tag_suggestion_funky')), findsOneWidget);
      expect(find.byType(TagCard), findsNothing);
    });

    testWidgets('creates tag from empty-state suggestion chip', (tester) async {
      await _pumpTagsScreen(
        tester,
        tagRepository: tagRepository,
        tagIdGenerator: () => 'tag-funky',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tag_suggestion_funky')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_editor_add')), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Name'))
            .controller
            ?.text,
        'Funky',
      );

      await tester.tap(find.byKey(const Key('tag_editor_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_card_tag-funky')), findsOneWidget);
      expect(find.text('Funky'), findsOneWidget);
    });

    testWidgets('creates tag from add dialog', (tester) async {
      await _pumpTagsScreen(
        tester,
        tagRepository: tagRepository,
        tagIdGenerator: () => 'tag-test',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tags_add_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_editor_add')), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Practice',
      );

      await tester.tap(find.byKey(const Key('tag_editor_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_card_tag-test')), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('0 shots'), findsOneWidget);

      final saved = await tagRepository.getTagById('tag-test');
      expect(saved, isNotNull);
      expect(saved!.name, 'Practice');
    });

    testWidgets('shows linked shot count on tag card', (tester) async {
      const tag = Tag(id: 'tag-linked', name: 'Linked Tag');
      await tagRepository.upsertTag(tag);
      await shotRepository.insertShot(
        Shot(
          id: 'shot-1',
          startedAt: DateTime.utc(2026, 6, 29, 10),
        ),
      );
      await tagRepository.setTagsForShot('shot-1', [tag.id]);

      await _pumpTagsScreen(tester, tagRepository: tagRepository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_card_tag-linked')), findsOneWidget);
      expect(find.text('1 shot'), findsOneWidget);
    });

    testWidgets('deletes tag from card action', (tester) async {
      const tag = Tag(id: 'tag-delete', name: 'Delete Me');
      await tagRepository.upsertTag(tag);

      await _pumpTagsScreen(tester, tagRepository: tagRepository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tag_delete_tag-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_card_tag-delete')), findsNothing);
      expect(await tagRepository.getTagById(tag.id), isNull);
    });
  });
}

Future<void> _pumpTagsScreen(
  WidgetTester tester, {
  required TagRepository tagRepository,
  TagIdGenerator? tagIdGenerator,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TagsScreen(
        tagRepository: tagRepository,
        tagIdGenerator: tagIdGenerator ?? generateTagId,
      ),
    ),
  );
}