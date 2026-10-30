import 'dart:async';
import 'package:my_car/features/records/models/activity_record.dart';
import 'package:my_car/features/records/repositories/activity_repository.dart';
import 'package:my_car/features/records/utils/record_calculations.dart';

class FakeActivityRepository implements ActivityRepository {
  final records = <String, List<ActivityRecord>>{};
  final changes = <String, StreamController<List<ActivityRecord>>>{};
  final removed = <String, ActivityRecord>{};
  String? failure;
  StreamController<List<ActivityRecord>> channel(String id) =>
      changes.putIfAbsent(id, () => StreamController.broadcast(sync: true));
  @override
  Stream<List<ActivityRecord>> watch(String id) => Stream.multi((controller) {
    controller.add(records[id] ?? []);
    final subscription = channel(
      id,
    ).stream.listen(controller.add, onError: controller.addError);
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> save(String vehicleId, ActivityRecord record) async {
    if (failure != null) throw RecordFailure(failure!);
    final list = [...records[vehicleId] ?? <ActivityRecord>[]];
    final id = record.id.isEmpty ? 'r-${list.length}' : record.id;
    list.removeWhere((r) => r.id == id);
    list.add(ActivityRecord.fromMap(id, record.toMap()));
    final invalid = RecordCalculations.validateTimeline(list);
    if (invalid != null) throw RecordFailure(invalid);
    list.sort((a, b) => RecordCalculations.compare(b, a));
    records[vehicleId] = list;
    channel(vehicleId).add(list);
  }

  @override
  Future<void> archive(String vehicleId, String id, bool archived) async {
    final list = [...records[vehicleId] ?? <ActivityRecord>[]];
    if (archived) {
      removed[id] = list.firstWhere((r) => r.id == id);
      list.removeWhere((r) => r.id == id);
    } else {
      list.add(removed.remove(id)!);
    }
    list.sort((a, b) => RecordCalculations.compare(b, a));
    records[vehicleId] = list;
    channel(vehicleId).add(list);
  }
}
