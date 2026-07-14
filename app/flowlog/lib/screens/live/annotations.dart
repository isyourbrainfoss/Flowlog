import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Mutable annotation list for a live or reviewed shot session.
class ShotAnnotationController extends ChangeNotifier {
  ShotAnnotationController([List<ShotAnnotation>? initial]) {
    if (initial != null) {
      _annotations.addAll(initial);
    }
  }

  final List<ShotAnnotation> _annotations = [];

  List<ShotAnnotation> get annotations => List.unmodifiable(_annotations);

  bool get canUndo => _annotations.isNotEmpty;

  void add(ShotAnnotation annotation) {
    _annotations.add(annotation);
    notifyListeners();
  }

  void markChannel({required int elapsedMs}) {
    add(ShotAnnotationHelpers.channelMark(_annotations, elapsedMs: elapsedMs));
  }

  void addNote({required int elapsedMs, required String label}) {
    add(ShotAnnotationHelpers.note(elapsedMs: elapsedMs, label: label.trim()));
  }

  ShotAnnotation? undo() {
    if (_annotations.isEmpty) {
      return null;
    }
    final removed = _annotations.removeLast();
    notifyListeners();
    return removed;
  }

  void clear() {
    if (_annotations.isEmpty) {
      return;
    }
    _annotations.clear();
    notifyListeners();
  }
}

/// Prompts for a note label at [elapsedMs] and adds it via [controller].
Future<void> promptShotNoteAnnotation({
  required BuildContext context,
  required ShotAnnotationController controller,
  required int elapsedMs,
}) async {
  final label = await showDialog<String>(
    context: context,
    builder: (context) => _NoteAnnotationDialog(elapsedMs: elapsedMs),
  );

  if (label == null || label.trim().isEmpty || !context.mounted) {
    return;
  }

  controller.addNote(elapsedMs: elapsedMs, label: label);
}

class _NoteAnnotationDialog extends StatefulWidget {
  const _NoteAnnotationDialog({required this.elapsedMs});

  final int elapsedMs;

  @override
  State<_NoteAnnotationDialog> createState() => _NoteAnnotationDialogState();
}

class _NoteAnnotationDialogState extends State<_NoteAnnotationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (widget.elapsedMs / 1000).toStringAsFixed(1);

    return AlertDialog(
      key: const Key('annotation_note_dialog'),
      title: const Text('Add note'),
      content: TextField(
        key: const Key('annotation_note_field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Note at ${seconds}s',
          hintText: 'e.g. First drops',
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('annotation_note_save'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _submit() {
    final label = _controller.text.trim();
    if (label.isEmpty) {
      return;
    }
    Navigator.of(context).pop(label);
  }
}

/// Bottom sheet: mark a channel switch or add a note at [elapsedMs].
Future<void> promptChartAnnotationAction({
  required BuildContext context,
  required ShotAnnotationController controller,
  required int elapsedMs,
}) async {
  final seconds = (elapsedMs / 1000).toStringAsFixed(1);
  final action = await showModalBottomSheet<ChartAnnotationAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'At ${seconds}s',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ListTile(
              key: const Key('annotate_mark_channel_here'),
              leading: const Icon(Icons.swap_vert),
              title: const Text('Mark channel here'),
              subtitle: const Text('Vertical marker at this point in the shot'),
              onTap: () =>
                  Navigator.pop(context, ChartAnnotationAction.channel),
            ),
            ListTile(
              key: const Key('annotate_add_note'),
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const Text('Add note'),
              onTap: () => Navigator.pop(context, ChartAnnotationAction.note),
            ),
          ],
        ),
      );
    },
  );

  if (!context.mounted || action == null) {
    return;
  }

  switch (action) {
    case ChartAnnotationAction.channel:
      controller.markChannel(elapsedMs: elapsedMs);
    case ChartAnnotationAction.note:
      await promptShotNoteAnnotation(
        context: context,
        controller: controller,
        elapsedMs: elapsedMs,
      );
  }
}

enum ChartAnnotationAction {
  channel,
  note,
}

/// Undo control for annotations shown under the live chart.
/// Marking is done via long-press on the chart (see promptChartAnnotationAction).
class AnnotationControls extends StatelessWidget {
  const AnnotationControls({
    required this.controller,
    super.key,
  });

  final ShotAnnotationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('undo_annotation_button'),
              tooltip: 'Undo last annotation',
              onPressed: controller.canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo),
            ),
            const SizedBox(height: 6),
            Text(
              'Long-press chart to mark channel or add note · undo to remove',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}