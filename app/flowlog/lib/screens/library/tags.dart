import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Generates a unique tag id for persistence.
typedef TagIdGenerator = String Function();

/// Default id format: `tag-<utc-milliseconds>`.
String generateTagId() {
  return 'tag-${DateTime.now().toUtc().millisecondsSinceEpoch}';
}

/// Tag list with CRUD and linked shot counts.
class TagsScreen extends StatefulWidget {
  const TagsScreen({
    super.key,
    this.tagRepository,
    this.tagIdGenerator = generateTagId,
  });

  /// Optional repository override for tests or dependency injection.
  final TagRepository? tagRepository;

  /// Generates ids for newly created tags.
  final TagIdGenerator tagIdGenerator;

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  TagRepository? _tagRepository;
  FlowlogDatabase? _database;
  bool _ownsRepository = false;
  late Future<List<TagWithShotCount>> _tagsFuture;

  @override
  void initState() {
    super.initState();
    _tagsFuture = _loadTags();
  }

  Future<TagRepository> _ensureRepository() async {
    if (widget.tagRepository != null) {
      return widget.tagRepository!;
    }
    if (_tagRepository != null) {
      return _tagRepository!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _tagRepository = TagRepository(_database!);
    _ownsRepository = true;
    return _tagRepository!;
  }

  Future<List<TagWithShotCount>> _loadTags() async {
    final repository = await _ensureRepository();
    return repository.listTagsWithShotCounts();
  }

  Future<void> _refresh() async {
    setState(() {
      _tagsFuture = _loadTags();
    });
    await _tagsFuture;
  }

  Future<void> _openTagEditor({Tag? tag, String? initialName}) async {
    final repository = await _ensureRepository();
    if (!mounted) {
      return;
    }
    final saved = await showTagEditorDialog(
      context: context,
      tag: tag,
      initialName: initialName,
      tagIdGenerator: widget.tagIdGenerator,
    );

    if (!mounted || saved == null) {
      return;
    }

    if (tag == null) {
      await repository.upsertTag(saved);
    } else {
      await repository.updateTag(saved);
    }

    await _refresh();
  }

  Future<void> _deleteTag(Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete tag'),
        content: Text(
          'Delete "${tag.name}"? Linked shots keep their other tags.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final repository = await _ensureRepository();
    await repository.deleteTag(tag.id);
    await _refresh();
  }

  @override
  void dispose() {
    if (_ownsRepository) {
      _database?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TagWithShotCount>>(
      future: _tagsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load tags: ${snapshot.error}'),
          );
        }

        final tags = snapshot.data ?? const <TagWithShotCount>[];

        return Scaffold(
          body: tags.isEmpty
              ? _EmptyTagsState(
                  onAddTag: ({String? initialName}) =>
                      _openTagEditor(initialName: initialName),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final entry = tags[index];
                      return TagCard(
                        entry: entry,
                        onTap: () => _openTagEditor(tag: entry.tag),
                        onDelete: () => _deleteTag(entry.tag),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            key: const Key('tags_add_fab'),
            onPressed: () => _openTagEditor(),
            tooltip: 'Add tag',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// Empty library tags state with quick-start suggestions.
class _EmptyTagsState extends StatelessWidget {
  const _EmptyTagsState({required this.onAddTag});

  final Future<void> Function({String? initialName}) onAddTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No tags yet',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tags organize shots in History filters — e.g. Practice, Dial-in, Funky.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final suggestion in const ['Practice', 'Dial-in', 'Funky'])
                    ActionChip(
                      key: Key('tag_suggestion_${suggestion.toLowerCase()}'),
                      label: Text(suggestion),
                      onPressed: () => onAddTag(initialName: suggestion),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('tags_add_empty_button'),
                onPressed: () => onAddTag(),
                icon: const Icon(Icons.add),
                label: const Text('Add tag'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Summary card for a tag in the library list.
class TagCard extends StatelessWidget {
  const TagCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final TagWithShotCount entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = entry.tag;

    return Card(
      key: Key('tag_card_${tag.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  tag.name,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Chip(
                key: Key('tag_shot_count_${tag.id}'),
                label: Text(
                  entry.shotCount == 1
                      ? '1 shot'
                      : '${entry.shotCount} shots',
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                key: Key('tag_delete_${tag.id}'),
                tooltip: 'Delete tag',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog for creating or editing a tag.
Future<Tag?> showTagEditorDialog({
  required BuildContext context,
  Tag? tag,
  String? initialName,
  TagIdGenerator tagIdGenerator = generateTagId,
}) {
  return showDialog<Tag>(
    context: context,
    builder: (dialogContext) => _TagEditorDialog(
      tag: tag,
      initialName: initialName,
      tagIdGenerator: tagIdGenerator,
    ),
  );
}

class _TagEditorDialog extends StatefulWidget {
  const _TagEditorDialog({
    required this.tag,
    required this.initialName,
    required this.tagIdGenerator,
  });

  final Tag? tag;
  final String? initialName;
  final TagIdGenerator tagIdGenerator;

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.tag?.name ?? widget.initialName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(
      context,
      Tag(
        id: widget.tag?.id ?? widget.tagIdGenerator(),
        name: _nameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.tag != null;

    return AlertDialog(
      key: Key(isEditing ? 'tag_editor_edit' : 'tag_editor_add'),
      title: Text(isEditing ? 'Edit tag' : 'Add tag'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('tag_editor_save'),
          onPressed: _save,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}