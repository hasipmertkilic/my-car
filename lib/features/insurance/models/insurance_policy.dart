import 'package:cloud_firestore/cloud_firestore.dart';

const cascoLevels = ['Dar Kasko', 'Kasko', 'Genişletilmiş Kasko', 'Tam Kasko'];

class InsurancePolicy {
  const InsurancePolicy({
    this.id = '',
    required this.kind,
    required this.company,
    required this.number,
    required this.startDate,
    required this.endDate,
    required this.premiumKurus,
    this.level = '',
    this.step,
    this.notes = '',
    this.archived = false,
  });
  final String id, kind, company, number, level, notes;
  final DateTime startDate, endDate;
  final int premiumKurus;
  final int? step;
  final bool archived;
  bool get isTraffic => kind == 'traffic';
  String get title => isTraffic ? 'Trafik sigortası' : 'Kasko';
  String get levelLabel => isTraffic
      ? (step == null ? 'Basamak belirtilmedi' : '$step. basamak')
      : level;
  bool get valid =>
      ['traffic', 'casco'].contains(kind) &&
      company.trim().isNotEmpty &&
      company.length <= 100 &&
      number.trim().isNotEmpty &&
      number.length <= 100 &&
      notes.length <= 1000 &&
      premiumKurus > 0 &&
      premiumKurus <= 100000000 &&
      startDate.year >= 1900 &&
      endDate.year <= 2100 &&
      endDate.isAfter(startDate) &&
      (isTraffic
          ? level.isEmpty && (step == null || (step! >= 0 && step! <= 8))
          : cascoLevels.contains(level) && step == null);
  int daysUntil(DateTime now) => day(endDate).difference(day(now)).inDays;
  bool started(DateTime now) => !day(startDate).isAfter(day(now));
  bool active(DateTime now) => started(now) && daysUntil(now) >= 0;
  String status(DateTime now) => !started(now)
      ? '${day(startDate).difference(day(now)).inDays} gün sonra başlayacak'
      : daysUntil(now) < 0
      ? 'Süresi ${-daysUntil(now)} gün önce doldu'
      : daysUntil(now) == 0
      ? 'Bugün sona eriyor'
      : 'Bitmesine ${daysUntil(now)} gün kaldı';
  static DateTime day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
  Map<String, dynamic> toMap() => {
    'kind': kind,
    'company': company,
    'number': number,
    'startDate': Timestamp.fromDate(day(startDate)),
    'endDate': Timestamp.fromDate(day(endDate)),
    'premiumKurus': premiumKurus,
    'level': level,
    'step': step,
    'notes': notes,
    'archived': archived,
  };
  factory InsurancePolicy.fromMap(String id, Map<String, dynamic> data) {
    DateTime date(String key) {
      final value = (data[key] as Timestamp).toDate().toUtc();
      return DateTime(value.year, value.month, value.day);
    }

    return InsurancePolicy(
      id: id,
      kind: data['kind'] as String,
      company: data['company'] as String,
      number: data['number'] as String,
      startDate: date('startDate'),
      endDate: date('endDate'),
      premiumKurus: data['premiumKurus'] as int,
      level: data['level'] as String,
      step: data['step'] as int?,
      notes: data['notes'] as String,
      archived: data['archived'] as bool,
    );
  }
}

InsurancePolicy? relevantPolicy(
  List<InsurancePolicy> policies,
  String kind,
  DateTime now,
) {
  final candidates = policies
      .where((p) => !p.archived && p.kind == kind)
      .toList();
  final current = candidates.where((p) => p.active(now)).toList()
    ..sort((a, b) => b.endDate.compareTo(a.endDate));
  if (current.isNotEmpty) return current.first;
  final future = candidates.where((p) => !p.started(now)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  if (future.isNotEmpty) return future.first;
  candidates.sort((a, b) => b.endDate.compareTo(a.endDate));
  return candidates.firstOrNull;
}
