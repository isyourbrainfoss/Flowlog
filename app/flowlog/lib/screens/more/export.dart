import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// How multiple shots are packaged for export.
enum BatchExportFormat {
  /// One CSV document with each shot separated by a blank line.
  combinedCsv,

  /// One CSV file per shot (zip archive is a stub until D5 import needs it).
  zip,
}

/// A named file entry used for zip-style batch export.
@immutable
class ExportFileEntry {
  const ExportFileEntry({
    required this.filename,
    required this.content,
  });

  final String filename;
  final String content;
}

/// Result of building a batch export payload.
@immutable
class BatchExportPayload {
  BatchExportPayload({
    required this.format,
    this.combinedCsv,
    this.files = const [],
  }) {
    assert(
      format == BatchExportFormat.combinedCsv
          ? combinedCsv != null && files.isEmpty
          : combinedCsv == null && files.isNotEmpty,
    );
  }

  final BatchExportFormat format;
  final String? combinedCsv;
  final List<ExportFileEntry> files;
}

/// Outcome of a platform save or share action.
@immutable
class ExportOutcome {
  const ExportOutcome({
    required this.success,
    this.message,
    this.savedPath,
    this.sharedFilenames = const [],
  });

  const ExportOutcome.cancelled()
      : success = false,
        message = 'Export cancelled',
        savedPath = null,
        sharedFilenames = const [];

  const ExportOutcome.saved(String path)
      : success = true,
        message = 'Saved export',
        savedPath = path,
        sharedFilenames = const [];

  const ExportOutcome.shared(List<String> filenames)
      : success = true,
        message = 'Shared export',
        savedPath = null,
        sharedFilenames = filenames;

  final bool success;
  final String? message;
  final String? savedPath;
  final List<String> sharedFilenames;
}

/// Platform I/O for batch export (save on desktop, share on mobile).
abstract class ExportActions {
  Future<ExportOutcome> saveTextFile({
    required String suggestedName,
    required String content,
  });

  Future<ExportOutcome> shareFiles(List<ExportFileEntry> files);
}

/// Test-friendly stub that records save/share requests without platform plugins.
class StubExportActions implements ExportActions {
  StubExportActions({this.saveDirectory});

  final String? saveDirectory;

  String? lastSavedPath;
  String? lastSavedContent;
  List<ExportFileEntry> lastSharedFiles = const [];
  int saveCalls = 0;
  int shareCalls = 0;

  @override
  Future<ExportOutcome> saveTextFile({
    required String suggestedName,
    required String content,
  }) async {
    saveCalls++;
    final directory = saveDirectory ?? Directory.systemTemp.path;
    Directory(directory).createSync(recursive: true);
    final path = '$directory/$suggestedName';
    lastSavedPath = path;
    lastSavedContent = content;
    await File(path).writeAsString(content);
    return ExportOutcome.saved(path);
  }

  @override
  Future<ExportOutcome> shareFiles(List<ExportFileEntry> files) async {
    shareCalls++;
    lastSharedFiles = List<ExportFileEntry>.from(files);
    return ExportOutcome.shared(files.map((file) => file.filename).toList());
  }
}

/// Linux/desktop save dialog via [getSaveLocation].
class LinuxExportActions implements ExportActions {
  @override
  Future<ExportOutcome> saveTextFile({
    required String suggestedName,
    required String content,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
        XTypeGroup(label: 'Text', extensions: ['txt']),
      ],
    );

    if (location == null) {
      return const ExportOutcome.cancelled();
    }

    final file = File(location.path);
    await file.writeAsString(content);
    return ExportOutcome.saved(file.path);
  }

  @override
  Future<ExportOutcome> shareFiles(List<ExportFileEntry> files) async {
    if (files.length == 1) {
      return saveTextFile(
        suggestedName: files.first.filename,
        content: files.first.content,
      );
    }

    final combined = files
        .map(
          (file) => '# ${file.filename}\n${file.content}',
        )
        .join('\n\n');
    return saveTextFile(
      suggestedName: 'flowlog-export.txt',
      content: combined,
    );
  }
}

/// Android share sheet via [SharePlus].
class AndroidExportActions implements ExportActions {
  @override
  Future<ExportOutcome> saveTextFile({
    required String suggestedName,
    required String content,
  }) async {
    final tempDir = Directory.systemTemp.createTempSync('flowlog-export');
    final file = File('${tempDir.path}/$suggestedName');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Flowlog export',
      ),
    );
    return ExportOutcome.shared([suggestedName]);
  }

  @override
  Future<ExportOutcome> shareFiles(List<ExportFileEntry> files) async {
    final tempDir = Directory.systemTemp.createTempSync('flowlog-export');
    final xFiles = <XFile>[];

    for (final entry in files) {
      final file = File('${tempDir.path}/${entry.filename}');
      await file.writeAsString(entry.content);
      xFiles.add(XFile(file.path, name: entry.filename));
    }

    await SharePlus.instance.share(
      ShareParams(
        files: xFiles,
        subject: 'Flowlog export',
      ),
    );
    return ExportOutcome.shared(files.map((file) => file.filename).toList());
  }
}

ExportActions defaultExportActions() {
  if (kIsWeb) {
    return StubExportActions();
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => AndroidExportActions(),
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS =>
      LinuxExportActions(),
    _ => StubExportActions(),
  };
}

/// Builds a deterministic batch export payload from [shots].
BatchExportPayload buildBatchExport(
  List<Shot> shots, {
  BatchExportFormat format = BatchExportFormat.combinedCsv,
}) {
  if (shots.isEmpty) {
    throw ArgumentError.value(shots, 'shots', 'must not be empty');
  }

  switch (format) {
    case BatchExportFormat.combinedCsv:
      return BatchExportPayload(
        format: format,
        combinedCsv: shots.map(exportShotToCsv).join('\n\n'),
      );
    case BatchExportFormat.zip:
      return BatchExportPayload(
        format: format,
        files: [
          for (final shot in shots)
            ExportFileEntry(
              filename: '${shot.id}.csv',
              content: exportShotToCsv(shot),
            ),
        ],
      );
  }
}

/// Dispatches [payload] to the platform [actions].
Future<ExportOutcome> deliverBatchExport(
  BatchExportPayload payload, {
  required ExportActions actions,
  String combinedFilename = 'flowlog-shots.csv',
}) {
  switch (payload.format) {
    case BatchExportFormat.combinedCsv:
      return actions.saveTextFile(
        suggestedName: combinedFilename,
        content: payload.combinedCsv!,
      );
    case BatchExportFormat.zip:
      return actions.shareFiles(payload.files);
  }
}

/// Batch export UI: select shots, choose format, save or share.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    this.shotRepository,
    this.exportActions,
  });

  final ShotRepository? shotRepository;
  final ExportActions? exportActions;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ShotRepository? _shotRepository;
  FlowlogDatabase? _database;

  late final ExportActions _actions;
  late Future<List<Shot>> _shotsFuture;

  final Set<String> _selectedShotIds = {};
  BatchExportFormat _format = BatchExportFormat.combinedCsv;
  bool _isExporting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _actions = widget.exportActions ?? defaultExportActions();
    _shotsFuture = _loadShots();
  }

  Future<ShotRepository> _ensureRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    _database = await openFlowlogDatabase();
    _shotRepository = ShotRepository(_database!);
    return _shotRepository!;
  }

  Future<List<Shot>> _loadShots() async {
    final repository = await _ensureRepository();
    final shots = await repository.listShots(includeSamples: true);
    if (mounted && _selectedShotIds.isEmpty && shots.isNotEmpty) {
      setState(() {
        _selectedShotIds.addAll(shots.map((shot) => shot.id));
      });
    }
    return shots;
  }

  Future<void> _refresh() async {
    setState(() {
      _shotsFuture = _loadShots();
    });
    await _shotsFuture;
  }

  Future<void> _exportSelected() async {
    final snapshot = await _shotsFuture;
    final selected = snapshot
        .where((shot) => _selectedShotIds.contains(shot.id))
        .toList();

    if (selected.isEmpty) {
      setState(() {
        _statusMessage = 'Select at least one shot to export.';
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    try {
      final payload = buildBatchExport(selected, format: _format);
      final outcome = await deliverBatchExport(
        payload,
        actions: _actions,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = outcome.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Shot>>(
      future: _shotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load shots: ${snapshot.error}'),
          );
        }

        final shots = snapshot.data ?? const <Shot>[];

        if (shots.isEmpty) {
          return const Center(
            child: Text('No saved shots to export yet'),
          );
        }

        final allSelected = _selectedShotIds.length == shots.length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<BatchExportFormat>(
                    segments: const [
                      ButtonSegment(
                        value: BatchExportFormat.combinedCsv,
                        label: Text('Combined CSV'),
                        icon: Icon(Icons.table_rows),
                      ),
                      ButtonSegment(
                        value: BatchExportFormat.zip,
                        label: Text('ZIP (stub)'),
                        icon: Icon(Icons.folder_zip),
                      ),
                    ],
                    selected: {_format},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _format = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedShotIds.clear();
                            } else {
                              _selectedShotIds
                                ..clear()
                                ..addAll(shots.map((shot) => shot.id));
                            }
                          });
                        },
                        child: Text(allSelected ? 'Clear all' : 'Select all'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        key: const Key('export_submit_button'),
                        onPressed:
                            _isExporting || _selectedShotIds.isEmpty
                                ? null
                                : _exportSelected,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.ios_share),
                        label: Text(_isExporting ? 'Exporting…' : 'Export'),
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: shots.length,
                  itemBuilder: (context, index) {
                    final shot = shots[index];
                    final selected = _selectedShotIds.contains(shot.id);
                    final dateLabel = _formatShotDate(context, shot);

                    return CheckboxListTile(
                      key: Key('export_shot_${shot.id}'),
                      value: selected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked ?? false) {
                            _selectedShotIds.add(shot.id);
                          } else {
                            _selectedShotIds.remove(shot.id);
                          }
                        });
                      },
                      title: Text(shot.id),
                      subtitle: Text(
                        '$dateLabel · ${shot.samples.length} samples',
                      ),
                      secondary: const Icon(Icons.coffee),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatShotDate(BuildContext context, Shot shot) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatShortDate(shot.startedAt.toLocal());
  }
}