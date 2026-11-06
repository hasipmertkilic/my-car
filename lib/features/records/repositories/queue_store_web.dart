import 'package:shared_preferences/shared_preferences.dart';
import 'dart:js_interop';
import 'queue_store.dart';

@JS('navigator.locks.request')
external JSPromise<JSAny?> _requestLock(JSString name, JSFunction callback);

QueueStore createQueueStore(String uid) => _BrowserQueueStore(uid);

class _BrowserQueueStore implements QueueStore {
  _BrowserQueueStore(String uid) : key = 'mycar.records.$uid';
  final String key;
  final storage = SharedPreferencesAsync();
  String? _previous;
  @override
  Future<String?> read() async {
    _previous = await storage.getString(key);
    return _previous;
  }

  @override
  Future<void> write(String data) async {
    await _requestLock(
      key.toJS,
      ((JSAny? lock) {
        return _writeLocked(data).toJS;
      }).toJS,
    ).toDart;
  }

  Future<JSAny?> _writeLocked(String data) async {
    if (await storage.getString(key) != _previous) {
      throw const QueueStoreConflict();
    }
    await storage.setString(key, data);
    _previous = data;
    return null;
  }
}
