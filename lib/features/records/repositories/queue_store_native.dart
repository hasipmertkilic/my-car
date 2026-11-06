import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'queue_store.dart';

QueueStore createQueueStore(String uid) => FileQueueStore(uid);

class FileQueueStore implements QueueStore {
  FileQueueStore(this.uid, {Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;
  final String uid;
  final Future<Directory> Function() _directory;
  String? _previous;
  Future<File> _file() async {
    final folder = await _directory();
    await folder.create(recursive: true);
    final key = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return File('${folder.path}/records-$key.json');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    final backup = File('${file.path}.bak');
    _previous = await file.exists()
        ? await file.readAsString()
        : await backup.exists()
        ? await backup.readAsString()
        : null;
    return _previous;
  }

  @override
  Future<void> write(String data) async {
    final file = await _file();
    final lock = await File('${file.path}.lock').open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      await _writeFile(file, data);
    } finally {
      await lock.close();
    }
  }

  Future<void> _writeFile(File file, String data) async {
    final temp = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    final current = await file.exists()
        ? await file.readAsString()
        : await backup.exists()
        ? await backup.readAsString()
        : null;
    if (current != _previous) throw const QueueStoreConflict();
    await temp.writeAsString(data, flush: true);
    if (await file.exists()) {
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    }
    await temp.rename(file.path);
    _previous = data;
    try {
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      // The new primary file has already been flushed and committed.
    }
  }
}
