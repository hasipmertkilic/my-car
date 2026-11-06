import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/records/models/activity_record.dart';
import 'package:my_car/features/records/repositories/activity_repository.dart';
import 'package:my_car/features/records/repositories/offline_activity_repository.dart';
import 'package:my_car/features/records/repositories/queue_store.dart';
import 'package:my_car/features/records/repositories/queue_store_native.dart';
import 'widget_test.dart' show authenticatedApp;
import 'activity_test.dart' show tap, enter;

class MemoryQueueStore implements QueueStore {
  String? data;
  bool failWrite = false;
  Completer<void>? pauseWrite;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('disk full');
    await pauseWrite?.future;
    data = value;
  }
}

class TestBackend implements QueuedActivityBackend {
  final rows = <String, ActivityRecord>{};
  final archived = <String>{};
  int writes = 0;
  bool loseAcknowledgement = false;
  @override
  Stream<List<ActivityRecord>> watch(String vehicleId) =>
      Stream.value(rows.values.where((r) => !archived.contains(r.id)).toList());
  @override
  Future<void> save(String vehicleId, ActivityRecord record) =>
      saveQueued(vehicleId, record, create: record.id.isEmpty, base: null);
  @override
  Future<void> archive(String vehicleId, String id, bool value) =>
      archiveQueued(vehicleId, rows[id]!, value);
  @override
  Future<void> saveQueued(
    String vehicleId,
    ActivityRecord record, {
    required bool create,
    required String? base,
  }) async {
    final old = rows[record.id];
    if (old?.fingerprint == record.fingerprint &&
        !archived.contains(record.id)) {
      return;
    }
    if ((create && old != null) || (!create && old?.fingerprint != base)) {
      throw const RecordFailure('Sunucu kaydı değişti.');
    }
    rows[record.id] = record;
    writes++;
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw const RecordFailure('Bağlantı koptu.', retryable: true);
    }
  }

  @override
  Future<void> archiveQueued(
    String vehicleId,
    ActivityRecord record,
    bool value,
  ) async {
    if (rows[record.id]?.fingerprint != record.fingerprint) {
      throw const RecordFailure('Kayıt değişti.');
    }
    if (value) {
      archived.add(record.id);
    } else {
      archived.remove(record.id);
    }
  }
}

ActivityRecord expense({String id = '', int km = 100, int amount = 5000}) =>
    ActivityRecord(
      id: id,
      kind: 'expense',
      date: DateTime(2026, 11, 6),
      odometerKm: km,
      amountKurus: amount,
      category: 'Yıkama',
    );

void main() {
  test(
    'native file storage survives reopen, backup recovery and rejects a stale writer',
    () async {
      final folder = await Directory.systemTemp.createTemp('mycar-offline-');
      addTearDown(() async {
        if (!folder.absolute.path.startsWith(
          Directory.systemTemp.absolute.path,
        )) {
          throw StateError('Unexpected temporary directory');
        }
        await folder.delete(recursive: true);
      });
      final first = FileQueueStore('alice', directory: () async => folder);
      final stale = FileQueueStore('alice', directory: () async => folder);
      expect(await first.read(), isNull);
      expect(await stale.read(), isNull);
      await first.write('first');
      await expectLater(
        stale.write('stale'),
        throwsA(isA<QueueStoreConflict>()),
      );
      final reopened = FileQueueStore('alice', directory: () async => folder);
      expect(await reopened.read(), 'first');
      final file = folder.listSync().whereType<File>().firstWhere(
        (file) => file.path.endsWith('.json'),
      );
      await file.rename('${file.path}.bak');
      final recovered = FileQueueStore('alice', directory: () async => folder);
      expect(await recovered.read(), 'first');
      await recovered.write('recovered');
      expect(
        await FileQueueStore('alice', directory: () async => folder).read(),
        'recovered',
      );
      expect(
        await FileQueueStore('bob', directory: () async => folder).read(),
        isNull,
      );
    },
  );
  var nextId = 0;
  OfflineActivityRepository repository(
    MemoryQueueStore store,
    TestBackend backend,
    StreamController<bool> network, {
    bool Function()? active,
  }) {
    final repo = OfflineActivityRepository(
      backend: backend,
      store: store,
      newId: () => 'id-${nextId++}',
      connection: network.stream,
      active: active ?? () => true,
    );
    addTearDown(repo.dispose);
    return repo;
  }

  Future<void> drain(OfflineActivityRepository repo) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      await Future<void>.delayed(Duration.zero);
      if (!repo.state.syncing) return;
    }
    fail('Synchronization did not finish');
  }

  testWidgets(
    'offline expense through the normal form appears with a pending sync status',
    (tester) async {
      final store = MemoryQueueStore(),
          backend = TestBackend(),
          network = StreamController<bool>.broadcast(sync: true);
      addTearDown(network.close);
      final repo = repository(store, backend, network);
      await tester.pumpWidget(authenticatedApp(activities: repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Çevrimdışı •'), findsOneWidget);
      await tap(tester, 'Masraf ekle');
      await enter(tester, 'Toplam tutar (TL)', '350,50');
      await tap(tester, 'Kaydı kaydet');
      expect(repo.localRecords('bmw').single.amountKurus, 35050);
      expect(backend.rows, isEmpty);
      expect(find.text('1 kayıt gönderilmeyi bekliyor'), findsOneWidget);
      await tap(tester, '1 kayıt gönderilmeyi bekliyor');
      expect(find.text('Cihazdaki kayıtlar'), findsOneWidget);
      expect(find.text('Gönderilmeyi bekliyor'), findsOneWidget);
      network.add(true);
      await tester.pumpAndSettle();
      expect(repo.state.pending, isEmpty);
      expect(backend.rows.length, 1);
      expect(find.text('Bekleyen kayıt yok.'), findsOneWidget);
      repo.dispose();
    },
  );

  test(
    'reconnect during a durable edit cannot upload and drop the older version',
    () async {
      final store = MemoryQueueStore(),
          backend = TestBackend(),
          network = StreamController<bool>.broadcast(sync: true);
      addTearDown(network.close);
      final repo = repository(store, backend, network);
      await repo.save('car', expense());
      final id = repo.localRecords('car').single.id;
      store.pauseWrite = Completer<void>();
      final editing = repo.save('car', expense(id: id, amount: 9000));
      await Future<void>.delayed(Duration.zero);
      network.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(backend.rows, isEmpty);
      store.pauseWrite!.complete();
      await editing;
      await drain(repo);
      expect(backend.rows[id]!.amountKurus, 9000);
      expect(repo.state.pending, isEmpty);
    },
  );

  test(
    'offline save survives reopening and uses the same ID when synchronized',
    () async {
      final store = MemoryQueueStore(),
          backend = TestBackend(),
          network = StreamController<bool>.broadcast(sync: true);
      addTearDown(network.close);
      final first = repository(store, backend, network);
      await first.save('car', expense());
      final id = first.localRecords('car').single.id;
      expect(first.state.pending.length, 1);
      expect(backend.rows, isEmpty);
      first.dispose();
      final reopened = repository(store, backend, network);
      await reopened.ready;
      expect(reopened.localRecords('car').single.id, id);
      network.add(true);
      await drain(reopened);
      expect(reopened.state.pending, isEmpty);
      expect(backend.rows.keys, [id]);
      expect(backend.writes, 1);
    },
  );
  test(
    'lost acknowledgement is retried without duplicating a record',
    () async {
      final store = MemoryQueueStore(),
          backend = TestBackend()..loseAcknowledgement = true;
      final network = StreamController<bool>.broadcast(sync: true);
      addTearDown(network.close);
      final repo = repository(store, backend, network);
      await repo.save('car', expense());
      network.add(true);
      await drain(repo);
      expect(repo.state.pending.length, 1);
      await repo.sync();
      expect(repo.state.pending, isEmpty);
      expect(backend.rows.length, 1);
      expect(backend.writes, 1);
    },
  );
  test('failed durable write never reports successful local save', () async {
    final store = MemoryQueueStore()..failWrite = true, backend = TestBackend();
    final network = StreamController<bool>.broadcast(sync: true);
    addTearDown(network.close);
    final repo = repository(store, backend, network);
    await expectLater(
      repo.save('car', expense()),
      throwsA(isA<RecordFailure>()),
    );
    expect(repo.localRecords('car'), isEmpty);
    expect(repo.state.pending, isEmpty);
  });
  test(
    'queued edit and archive/restore preserve order across restart',
    () async {
      final store = MemoryQueueStore(),
          backend = TestBackend(),
          network = StreamController<bool>.broadcast(sync: true);
      addTearDown(network.close);
      final repo = repository(store, backend, network);
      await repo.save('car', expense());
      final id = repo.localRecords('car').single.id;
      await repo.archive('car', id, true);
      expect(repo.localRecords('car'), isEmpty);
      await repo.archive('car', id, false);
      await repo.save('car', expense(id: id, amount: 9000));
      network.add(true);
      await drain(repo);
      expect(repo.state.pending, isEmpty);
      expect(backend.rows[id]!.amountKurus, 9000);
      expect(backend.archived, isEmpty);
    },
  );
  test('server edit conflict stays visible and can be discarded', () async {
    final store = MemoryQueueStore(),
        backend = TestBackend(),
        network = StreamController<bool>.broadcast(sync: true);
    addTearDown(network.close);
    backend.rows['remote'] = expense(id: 'remote');
    final repo = repository(store, backend, network);
    final subscription = repo.watch('car').listen((_) {});
    addTearDown(subscription.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await repo.save('car', expense(id: 'remote', amount: 6000));
    backend.rows['remote'] = expense(id: 'remote', amount: 7000);
    network.add(true);
    await drain(repo);
    expect(repo.state.pending.single.error, isNotNull);
    expect(backend.rows['remote']!.amountKurus, 7000);
    await repo.discard(repo.state.pending.single.key);
    expect(repo.state.pending, isEmpty);
  });
  test(
    'sign-out guard prevents syncing another account and corrupt storage is preserved',
    () async {
      final store = MemoryQueueStore(),
          backend = TestBackend(),
          network = StreamController<bool>.broadcast(sync: true);
      addTearDown(network.close);
      var active = true;
      final repo = repository(store, backend, network, active: () => active);
      await repo.save('car', expense());
      active = false;
      network.add(true);
      await drain(repo);
      expect(backend.rows, isEmpty);
      expect(repo.state.pending.length, 1);
      final broken = MemoryQueueStore()..data = 'broken-json';
      final corrupt = repository(broken, backend, network);
      await corrupt.ready;
      await expectLater(
        corrupt.save('car', expense()),
        throwsA(isA<RecordFailure>()),
      );
      await expectLater(corrupt.retry(), throwsA(isA<RecordFailure>()));
      expect(broken.data, 'broken-json');
    },
  );
}
