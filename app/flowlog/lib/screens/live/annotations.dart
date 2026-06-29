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

/// Mark channel and undo controls shown under the live chart.
class AnnotationControls extends StatelessWidget {
  const AnnotationControls({
    required this.controller,
    required this.canMarkChannel,
    required this.onMarkChannel,
    super.key,
  });

  final ShotAnnotationController controller;
  final bool canMarkChannel;
  final VoidCallback onMarkChannel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.tonalIcon(
              key: const Key('mark_channel_button'),
              onPressed: canMarkChannel ? onMarkChannel : null,
              icon: const Icon(Icons.swap_vert),
              label: const Text('Mark channel'),
            ),
            IconButton(
              key: const Key('undo_annotation_button'),
              tooltip: 'Undo annotation',
              onPressed: controller.canUndo ? controller.undo : null,
              icon: const Icon(Icons.undo),
            ),
          ],
        );
      },
    );
  }
}