import 'dart:async';
import 'dart:io';

final Map<String, Future<void>> _pendingWrites = <String, Future<void>>{};

/// Writes [contents] to [file] atomically and serialized per path.
///
/// Settings are saved from slider drags and toggles without awaiting, so two
/// plain [File.writeAsString] calls on the same path can interleave and leave
/// trailing bytes from the longer payload (invalid JSON — the stores then fall
/// back to defaults). Writes here are queued per path, go to a sibling temp
/// file first, and are renamed into place so readers never see a partial file
/// (also covers the app being killed mid-write).
Future<void> writeStringAtomically(File file, String contents) {
  final key = file.absolute.path;
  final previous = _pendingWrites[key] ?? Future<void>.value();
  final next = previous
      .catchError((Object _) {})
      .then((_) => _writeViaTemp(file, contents));
  _pendingWrites[key] = next;
  return next.whenComplete(() {
    if (identical(_pendingWrites[key], next)) {
      _pendingWrites.remove(key);
    }
  });
}

Future<void> _writeViaTemp(File file, String contents) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(contents, flush: true);
  await temp.rename(file.path);
}
