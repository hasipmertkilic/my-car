import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class InspectionSchedule {
  const InspectionSchedule({
    required this.lastDate,
    required this.intervalYears,
    this.notes = '',
  });
  final DateTime lastDate;
  final int intervalYears;
  final String notes;
  DateTime get nextDate {
    final year = lastDate.year + intervalYears;
    final maxDay = DateTime(year, lastDate.month + 1, 0).day;
    return DateTime(year, lastDate.month, min(lastDate.day, maxDay));
  }

  int daysUntil(DateTime now) => DateTime.utc(
    nextDate.year,
    nextDate.month,
    nextDate.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  String status(DateTime now) {
    final days = daysUntil(now);
    return days < 0
        ? 'Muayene ${-days} gün gecikti'
        : days == 0
        ? 'Muayene tarihi bugün'
        : 'Muayeneye $days gün kaldı';
  }

  Map<String, dynamic> toMap() => {
    'lastDate': Timestamp.fromDate(
      DateTime.utc(lastDate.year, lastDate.month, lastDate.day),
    ),
    'nextDate': Timestamp.fromDate(
      DateTime.utc(nextDate.year, nextDate.month, nextDate.day),
    ),
    'intervalYears': intervalYears,
    'notes': notes,
  };
  factory InspectionSchedule.fromMap(Map<String, dynamic> data) {
    final date = (data['lastDate'] as Timestamp).toDate().toUtc();
    return InspectionSchedule(
      lastDate: DateTime(date.year, date.month, date.day),
      intervalYears: data['intervalYears'] as int,
      notes: data['notes'] as String,
    );
  }
}

class InspectionReminder {
  const InspectionReminder(this.vehicleId, this.vehicleName, this.schedule);
  final String vehicleId, vehicleName;
  final InspectionSchedule schedule;
}
