import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/features/records/models/activity_record.dart';
import 'package:my_car/features/records/utils/record_calculations.dart';

ActivityRecord fuel(
  String id,
  int km,
  int liters, {
  bool full = true,
  int day = 1,
  int month = 1,
}) => ActivityRecord(
  id: id,
  kind: 'fuel',
  date: DateTime(2026, month, day),
  odometerKm: km,
  amountKurus: liters * 5,
  category: 'Yakıt',
  litersMilli: liters,
  fullTank: full,
  fuelType: 'Benzin',
);
void main() {
  test('540 km için 42,3 litre tüketimi ve birim maliyet', () {
    final summary = RecordSummary([
      fuel('a', 124890, 40000),
      fuel('b', 125430, 42300, day: 2),
    ]);
    expect(summary.fuelMetrics.litersPer100Km, closeTo(7.8333333, 0.000001));
    expect(summary.fuelMetrics.kmPerLiter, closeTo(12.7659574, 0.000001));
    expect(summary.fuelMetrics.costPer100Km, closeTo(391.666666, 0.00001));
    final mixed = RecordSummary([
      fuel('a', 1000, 40000),
      fuel('b', 1500, 40000, day: 2),
      ActivityRecord(
        id: 'c',
        kind: 'fuel',
        date: DateTime(2026, 1, 3),
        odometerKm: 1800,
        amountKurus: 100000,
        category: 'Yakıt',
        litersMilli: 30000,
        fullTank: true,
        fuelType: 'LPG',
      ),
    ]);
    expect(mixed.fuelMetrics.litersPer100Km, isNull);
  });
  test(
    'İlk ve kapanmamış dolum tüketim hesabına girmez, kısmi dolumlar toplanır',
    () {
      final records = [
        fuel('a', 1000, 50000),
        fuel('b', 1200, 10000, full: false, day: 2),
        fuel('c', 1500, 25000, day: 3),
        fuel('d', 1700, 20000, full: false, day: 4),
      ];
      final summary = RecordSummary(records);
      expect(summary.fuelMetrics.litersPer100Km, closeTo(7, 0.000001));
      expect(summary.litersMilli, 105000);
      expect(RecordSummary([records.first]).fuelMetrics.litersPer100Km, isNull);
      expect(
        RecordSummary([
          fuel('a', 1000, 40000),
          fuel('b', 1000, 20000),
        ]).fuelMetrics.litersPer100Km,
        isNull,
      );
    },
  );
  test('Ağırlıklı tüketim ve aylık giderler çifte sayılmaz', () {
    final a = fuel('a', 1000, 40000, month: 12);
    final b = fuel('b', 1500, 40000, day: 2, month: 12);
    final expense = ActivityRecord(
      id: 'e',
      kind: 'expense',
      date: DateTime(2027, 1, 1),
      odometerKm: 1600,
      amountKurus: 10050,
      category: 'Yıkama',
    );
    final summary = RecordSummary([a, b, expense], now: DateTime(2027, 1, 5));
    expect(summary.monthlyKurus, 10050);
    expect(summary.annualKurus, 10050);
    expect(summary.totalKurus, a.amountKurus + b.amountKurus + 10050);
    expect(
      RecordSummary([
        fuel('a', 1000, 40000),
        fuel('b', 1500, 40000, day: 2),
        fuel('c', 2500, 60000, day: 3),
      ]).fuelMetrics.litersPer100Km,
      closeTo(100 / 1500 * 100, 0.000001),
    );
  });
  test(
    'Türkçe ondalıklar tam sayıya dönüşür; belirsiz binlikler reddedilir',
    () {
      expect(RecordCalculations.scaledNumber('1250,50', 2), 125050);
      expect(RecordCalculations.scaledNumber('42.3', 3), 42300);
      expect(RecordCalculations.scaledNumber('1.250,50', 2), isNull);
      expect(RecordCalculations.scaledNumber('NaN', 2), isNull);
    },
  );
  test('Geçmiş kayıt tarih sırasına göre doğrulanır', () {
    expect(
      RecordCalculations.validateTimeline([
        fuel('b', 2000, 40000, day: 2),
        fuel('a', 1000, 40000),
      ]),
      isNull,
    );
    expect(
      RecordCalculations.validateTimeline([
        fuel('a', 2000, 40000),
        fuel('b', 1000, 40000, day: 2),
      ]),
      isNotNull,
    );
  });
}
