import 'queue_store_native.dart'
    if (dart.library.js_interop) 'queue_store_web.dart'
    as platform;

abstract interface class QueueStore {
  Future<String?> read();
  Future<void> write(String data);
}

class QueueStoreConflict implements Exception {
  const QueueStoreConflict();
}

QueueStore deviceQueueStore(String uid) => platform.createQueueStore(uid);
