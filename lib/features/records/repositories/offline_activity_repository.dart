import 'dart:async';
import 'dart:convert';
import '../models/activity_record.dart';
import '../utils/record_calculations.dart';
import 'activity_repository.dart';
import 'queue_store.dart';

class PendingRecord {
  const PendingRecord({
    required this.key,
    required this.vehicleId,
    required this.record,
    required this.create,
    required this.base,
    this.archived,
    this.error,
  });
  final String key, vehicleId;
  final ActivityRecord record;
  final bool create;
  final String? base, error;
  final bool? archived;
  Map<String, dynamic> toJson() => {
    'key': key,
    'vehicleId': vehicleId,
    'id': record.id,
    'record': record.toLocalMap(),
    'create': create,
    'base': base,
    'archived': archived,
    'error': error,
  };
  factory PendingRecord.fromJson(Map<String, dynamic> data) => PendingRecord(
    key: data['key'] as String,
    vehicleId: data['vehicleId'] as String,
    record: ActivityRecord.fromLocalMap(
      data['id'] as String,
      Map<String, dynamic>.from(data['record'] as Map),
    ),
    create: data['create'] as bool,
    base: data['base'] as String?,
    archived: data['archived'] as bool?,
    error: data['error'] as String?,
  );
  PendingRecord withError(String? value) => PendingRecord(
    key: key,
    vehicleId: vehicleId,
    record: record,
    create: create,
    base: base,
    archived: archived,
    error: value,
  );
}

class OfflineRecordState {
  const OfflineRecordState({
    this.online = false,
    this.syncing = false,
    this.pending = const [],
    this.issue,
  });
  final bool online, syncing;
  final List<PendingRecord> pending;
  final String? issue;
}

class OfflineActivityRepository implements ActivityRepository {
  OfflineActivityRepository({
    required this.backend,
    required this.store,
    required this.newId,
    required Stream<bool> connection,
    required this.active,
  }) {
    ready = _load();
    _connection = connection.listen(
      (value) {
        online = value;
        _notify();
        if (value) unawaited(sync());
      },
      onError: (Object _) {
        online = false;
        _notify();
      },
    );
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (online) unawaited(sync());
    });
  }
  final QueuedActivityBackend backend;
  final QueueStore store;
  final String Function() newId;
  final bool Function() active;
  late final Future<void> ready;
  late final StreamSubscription<bool> _connection;
  Timer? _timer;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _states = StreamController<OfflineRecordState>.broadcast(sync: true);
  Map<String, List<ActivityRecord>> _cache = {};
  List<PendingRecord> _pending = [];
  final _undo = <String, ActivityRecord>{};
  Future<void> _tail = Future.value();
  bool online = false, _syncing = false, _disposed = false;
  String? _inflight, _issue;
  OfflineRecordState get state => OfflineRecordState(
    online: online,
    syncing: _syncing,
    pending: List.unmodifiable(_pending),
    issue: _issue,
  );
  Stream<OfflineRecordState> get states => Stream.multi((sink) {
    sink.add(state);
    final sub = _states.stream.listen(sink.add);
    sink.onCancel = sub.cancel;
  });
  Future<void> _load() async {
    try {
      final text = await store.read();
      if (text != null) {
        final data = jsonDecode(text) as Map;
        if (data['version'] != 1) throw const FormatException('queue-version');
        _pending = (data['pending'] as List)
            .map(
              (row) =>
                  PendingRecord.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        _cache = (data['cache'] as Map).map(
          (key, value) => MapEntry(
            key as String,
            (value as List)
                .map(
                  (row) => ActivityRecord.fromLocalMap(
                    row['id'] as String,
                    Map<String, dynamic>.from(row['data'] as Map),
                  ),
                )
                .toList(),
          ),
        );
      }
      _notify();
    } catch (_) {
      _issue =
          'Telefondaki kayıtlar okunamadı. Uygulama verilerini silmeden tekrar aç.';
      _notify();
      // Saving stays blocked instead of overwriting an unreadable queue.
    }
  }

  void _notify() {
    if (_disposed) return;
    _changes.add(null);
    _states.add(state);
  }

  Future<void> _locked(Future<void> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> _commit(
    List<PendingRecord> pending,
    Map<String, List<ActivityRecord>> cache,
  ) async {
    try {
      await store.write(
        jsonEncode({
          'version': 1,
          'pending': pending.map((p) => p.toJson()).toList(),
          'cache': cache.map(
            (key, rows) => MapEntry(
              key,
              rows.map((r) => {'id': r.id, 'data': r.toLocalMap()}).toList(),
            ),
          ),
        }),
      );
    } on QueueStoreConflict {
      _issue =
          'Cihazdaki kayıtlar başka bir oturumda güncellendi. Uygulamayı yeniden aç.';
      _notify();
      throw RecordFailure(_issue!);
    } catch (_) {
      throw const RecordFailure(
        'Telefona kayıt yazılamadı. Depolama alanını kontrol edip tekrar dene.',
      );
    }
    _pending = pending;
    _cache = cache;
    _notify();
  }

  List<ActivityRecord> localRecords(String vehicleId) {
    final rows = {
      for (final r in _cache[vehicleId] ?? <ActivityRecord>[]) r.id: r,
    };
    for (final op in _pending.where((op) => op.vehicleId == vehicleId)) {
      if (op.archived == true) {
        rows.remove(op.record.id);
      } else {
        rows[op.record.id] = op.record;
      }
    }
    return rows.values.toList()
      ..sort((a, b) => RecordCalculations.compare(b, a));
  }

  @override
  Stream<List<ActivityRecord>> watch(String vehicleId) => Stream.multi((sink) {
    StreamSubscription<void>? changes;
    StreamSubscription<List<ActivityRecord>>? remote;
    var cancelled = false;
    unawaited(() async {
      await ready;
      if (cancelled) return;
      sink.add(localRecords(vehicleId));
      changes = _changes.stream.listen(
        (_) => sink.add(localRecords(vehicleId)),
      );
      remote = backend
          .watch(vehicleId)
          .listen(
            (rows) {
              unawaited(
                _locked(() async {
                  if (_disposed || _issue != null) return;
                  await _commit([..._pending], {..._cache, vehicleId: rows});
                }).catchError((Object _) {
                  _issue =
                      'Geçmişin cihaz kopyası güncellenemedi. Depolama alanını kontrol et.';
                  _notify();
                }),
              );
            },
            onError: (Object _) {
              online = false;
              _notify();
            },
          );
    }());
    sink.onCancel = () async {
      cancelled = true;
      await changes?.cancel();
      await remote?.cancel();
    };
  });
  @override
  Future<void> save(String vehicleId, ActivityRecord record) async {
    await ready;
    await _locked(() async {
      if (_issue != null || !active()) {
        throw RecordFailure(_issue ?? 'Oturumunu kontrol et.');
      }
      final rows = localRecords(vehicleId);
      final old = rows.where((r) => r.id == record.id).firstOrNull;
      if (record.id.isNotEmpty && old == null) {
        throw const RecordFailure('Kayıt bulunamadı.');
      }
      final candidate = ActivityRecord.fromMap(
        record.id.isEmpty ? newId() : record.id,
        record.toMap(),
      );
      final invalid = RecordCalculations.validateTimeline([
        ...rows.where((r) => r.id != candidate.id),
        candidate,
      ]);
      if (invalid != null) throw RecordFailure(invalid);
      final last = _pending
          .where(
            (op) => op.vehicleId == vehicleId && op.record.id == candidate.id,
          )
          .lastOrNull;
      final same =
          last != null && last.archived == null && last.key != _inflight
          ? last
          : null;
      final pending = [..._pending];
      final op = PendingRecord(
        key: same?.key ?? newId(),
        vehicleId: vehicleId,
        record: candidate,
        create: same?.create ?? record.id.isEmpty,
        base: same?.base ?? old?.fingerprint,
      );
      if (same != null) {
        pending[pending.indexOf(same)] = op;
      } else {
        pending.add(op);
      }
      await _commit(pending, {..._cache});
    });
    unawaited(sync());
  }

  @override
  Future<void> archive(String vehicleId, String id, bool archived) async {
    await ready;
    await _locked(() async {
      if (_issue != null || !active()) {
        throw RecordFailure(_issue ?? 'Oturumunu kontrol et.');
      }
      final record =
          localRecords(vehicleId).where((r) => r.id == id).firstOrNull ??
          _undo['$vehicleId/$id'];
      if (record == null) throw const RecordFailure('Kayıt bulunamadı.');
      final rows = localRecords(vehicleId).where((r) => r.id != id).toList();
      if (!archived) rows.add(record);
      final invalid = RecordCalculations.validateTimeline(rows);
      if (invalid != null) throw RecordFailure(invalid);
      _undo['$vehicleId/$id'] = record;
      await _commit(
        [
          ..._pending,
          PendingRecord(
            key: newId(),
            vehicleId: vehicleId,
            record: record,
            create: false,
            base: record.fingerprint,
            archived: archived,
          ),
        ],
        {..._cache},
      );
    });
    unawaited(sync());
  }

  Future<void> retry() async {
    await ready;
    if (_issue != null) throw RecordFailure(_issue!);
    await _locked(
      () => _commit(_pending.map((op) => op.withError(null)).toList(), {
        ..._cache,
      }),
    );
    await sync();
  }

  Future<void> discard(String key) async {
    await ready;
    if (_issue != null) throw RecordFailure(_issue!);
    await _locked(() async {
      final op = _pending.where((p) => p.key == key).firstOrNull;
      if (op == null) return;
      if (_pending.any(
        (p) =>
            p.vehicleId == op.vehicleId &&
            p.record.id == op.record.id &&
            p.key == _inflight,
      )) {
        throw const RecordFailure(
          'Bu kayıt gönderiliyor. Biraz bekleyip tekrar dene.',
        );
      }
      await _commit(
        _pending
            .where(
              (p) => p.vehicleId != op.vehicleId || p.record.id != op.record.id,
            )
            .toList(),
        {..._cache},
      );
    });
  }

  Future<void> sync() async {
    await ready;
    if (_syncing || _disposed || !online || !active() || _issue != null) return;
    _syncing = true;
    _notify();
    try {
      while (!_disposed && online && active()) {
        PendingRecord? selected;
        await _locked(() async {
          final blocked = _pending
              .where((p) => p.error != null)
              .map((p) => p.vehicleId)
              .toSet();
          selected = _pending
              .where((p) => !blocked.contains(p.vehicleId))
              .firstOrNull;
          _inflight = selected?.key;
        });
        final op = selected;
        if (op == null) break;
        try {
          final request = op.archived == null
              ? backend.saveQueued(
                  op.vehicleId,
                  op.record,
                  create: op.create,
                  base: op.base,
                )
              : backend.archiveQueued(op.vehicleId, op.record, op.archived!);
          await request.timeout(const Duration(seconds: 15));
          if (_disposed) return;
          await _locked(() async {
            final rows = [..._cache[op.vehicleId] ?? <ActivityRecord>[]]
              ..removeWhere((r) => r.id == op.record.id);
            if (op.archived != true) rows.add(op.record);
            await _commit(_pending.where((p) => p.key != op.key).toList(), {
              ..._cache,
              op.vehicleId: rows,
            });
          });
        } on TimeoutException {
          break;
        } on RecordFailure catch (error) {
          if (error.retryable) break;
          await _locked(
            () => _commit(
              _pending
                  .map((p) => p.key == op.key ? p.withError(error.message) : p)
                  .toList(),
              {..._cache},
            ),
          );
        } catch (_) {
          break;
        } finally {
          _inflight = null;
        }
      }
    } finally {
      _syncing = false;
      _notify();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    unawaited(_connection.cancel());
    unawaited(_changes.close());
    unawaited(_states.close());
  }
}
