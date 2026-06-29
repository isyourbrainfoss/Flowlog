import 'package:flowlog/screens/live/annotations.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShotAnnotationController', () {
    test('mark channel increments labels and undo removes last', () {
      final controller = ShotAnnotationController();

      controller.markChannel(elapsedMs: 1000);
      controller.markChannel(elapsedMs: 5000);

      expect(controller.annotations, hasLength(2));
      expect(controller.annotations.first.label, 'Channel 1');
      expect(controller.annotations.last.label, 'Channel 2');

      controller.undo();
      expect(controller.annotations, hasLength(1));
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.annotations, isEmpty);
      expect(controller.canUndo, isFalse);
    });
  });

  group('buildShotFromSession', () {
    test('includes annotations on saved shot', () {
      const annotations = [
        ShotAnnotation(
          elapsedMs: 1200,
          label: 'Channel 1',
          type: ShotAnnotationType.channel,
        ),
      ];

      final shot = buildShotFromSession(
        samples: const [ShotSample(elapsedMs: 0, pressureBar: 0)],
        startedAt: DateTime.utc(2026, 6, 29, 10),
        annotations: annotations,
        id: 'shot-annot',
      );

      expect(shot.annotations, annotations);
    });
  });

  group('AnnotationControls', () {
    testWidgets('mark channel and undo buttons are present on live screen',
        (tester) async {
      final controller = ShotAnnotationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnnotationControls(
              controller: controller,
              canMarkChannel: true,
              onMarkChannel: () => controller.markChannel(elapsedMs: 1000),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('mark_channel_button')), findsOneWidget);
      expect(find.byKey(const Key('undo_annotation_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mark_channel_button')));
      await tester.pump();

      expect(controller.annotations, hasLength(1));

      await tester.tap(find.byKey(const Key('undo_annotation_button')));
      await tester.pump();

      expect(controller.annotations, isEmpty);
    });
  });

  group('promptShotNoteAnnotation', () {
    testWidgets('adds a note annotation from dialog', (tester) async {
      final controller = ShotAnnotationController();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () => promptShotNoteAnnotation(
                    context: context,
                    controller: controller,
                    elapsedMs: 2500,
                  ),
                  child: const Text('Annotate'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Annotate'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('annotation_note_dialog')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('annotation_note_field')),
        'Sweet spot',
      );
      await tester.tap(find.byKey(const Key('annotation_note_save')));
      await tester.pumpAndSettle();

      expect(controller.annotations, hasLength(1));
      expect(controller.annotations.single.label, 'Sweet spot');
      expect(controller.annotations.single.type, ShotAnnotationType.note);
      expect(controller.annotations.single.elapsedMs, 2500);
    });
  });
}