import 'dart:async';
import 'package:my_car/features/inspection/models/inspection_schedule.dart';
import 'package:my_car/features/inspection/repositories/inspection_repository.dart';

class FakeInspectionRepository implements InspectionRepository {
  final Map<String, InspectionSchedule> data = {};
  final Map<String, StreamController<InspectionSchedule?>> channels = {};
  String? failure;
  @override
  Stream<InspectionSchedule?> watch(String id) => Stream.multi((controller) {
    controller.add(data[id]);
    final stream = channels.putIfAbsent(
      id,
      () => StreamController.broadcast(sync: true),
    );
    final subscription = stream.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<void> save(String id, InspectionSchedule schedule) async {
    if (failure != null) throw InspectionFailure(failure!);
    data[id] = schedule;
    channels[id]?.add(schedule);
  }
}
