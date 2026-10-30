import '../models/activity_record.dart';

abstract final class RecordCalculations {
  static int compare(ActivityRecord a, ActivityRecord b) {
    final date = a.date.compareTo(b.date);
    if (date != 0) return date;
    final km = a.odometerKm.compareTo(b.odometerKm);
    return km == 0 ? a.id.compareTo(b.id) : km;
  }

  static String? validateTimeline(List<ActivityRecord> records) {
    final ordered = [...records]..sort(compare);
    for (var i = 1; i < ordered.length; i++) {
      if (ordered[i].odometerKm < ordered[i - 1].odometerKm) {
        return 'Bu kilometre, tarih sırasındaki diğer kayıtlarla uyuşmuyor. Tarihi veya kilometreyi kontrol et.';
      }
    }
    return null;
  }

  // Kullanıcı 42,3 veya 42.3 yazabilir. Para/litre tam sayı ölçekle saklanır.
  static int? scaledNumber(String text, int decimals) {
    final normalized = text.trim().replaceAll(',', '.');
    if (!RegExp('^\\d+(?:\\.\\d{1,$decimals})?\$').hasMatch(normalized)) {
      return null;
    }
    final parts = normalized.split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null) return null;
    var scale = 1;
    for (var i = 0; i < decimals; i++) {
      scale *= 10;
    }
    final fraction = parts.length == 2
        ? int.parse(parts[1].padRight(decimals, '0'))
        : 0;
    return whole * scale + fraction;
  }
}

class RecordSummary {
  RecordSummary(this.records, {DateTime? now}) : now = now ?? DateTime.now();
  final List<ActivityRecord> records;
  final DateTime now;
  int get totalKurus => records.fold(0, (sum, r) => sum + r.amountKurus);
  int get monthlyKurus => records
      .where((r) => r.date.year == now.year && r.date.month == now.month)
      .fold(0, (sum, r) => sum + r.amountKurus);
  int get annualKurus => records
      .where((r) => r.date.year == now.year)
      .fold(0, (sum, r) => sum + r.amountKurus);
  int get fuelKurus =>
      records.where((r) => r.isFuel).fold(0, (sum, r) => sum + r.amountKurus);
  int get litersMilli =>
      records.where((r) => r.isFuel).fold(0, (sum, r) => sum + r.litersMilli);
  Map<String, int> get categories {
    final totals = <String, int>{};
    for (final record in records) {
      totals.update(
        record.category,
        (value) => value + record.amountKurus,
        ifAbsent: () => record.amountKurus,
      );
    }
    return totals;
  }

  List<ActivityRecord> get ordered =>
      [...records]..sort(RecordCalculations.compare);
  int get observedKm => records.length < 2
      ? 0
      : ordered.last.odometerKm - ordered.first.odometerKm;
  // İlk dolu depo başlangıç noktasıdır; onun litre/tutarı aralığa dahil edilmez.
  FuelMetrics get fuelMetrics {
    final fuelRecords = ordered.where((r) => r.isFuel).toList();
    final latestFuelType = fuelRecords.lastOrNull?.fuelType;
    ActivityRecord? start;
    var pendingLiters = 0,
        pendingKurus = 0,
        totalLiters = 0,
        totalKm = 0,
        totalKurus = 0;
    for (final record in fuelRecords) {
      // Farklı yakıt türlerinin litre hesaplarını karıştırma.
      if (record.fuelType != latestFuelType) {
        start = null;
        pendingLiters = 0;
        pendingKurus = 0;
        continue;
      }
      if (start == null) {
        if (record.fullTank) start = record;
        continue;
      }
      pendingLiters += record.litersMilli;
      pendingKurus += record.amountKurus;
      if (record.fullTank) {
        final km = record.odometerKm - start.odometerKm;
        if (km > 0) {
          totalKm += km;
          totalLiters += pendingLiters;
          totalKurus += pendingKurus;
        }
        pendingLiters = 0;
        pendingKurus = 0;
        start = record;
      }
    }
    return FuelMetrics(totalLiters, totalKm, totalKurus);
  }
}

class FuelMetrics {
  const FuelMetrics(this.litersMilli, this.distanceKm, this.amountKurus);
  final int litersMilli, distanceKm, amountKurus;
  double? get litersPer100Km =>
      distanceKm > 0 ? litersMilli / 1000 / distanceKm * 100 : null;
  double? get kmPerLiter =>
      litersMilli > 0 ? distanceKm / (litersMilli / 1000) : null;
  double? get costPer100Km =>
      distanceKm > 0 ? amountKurus / 100 / distanceKm * 100 : null;
}
