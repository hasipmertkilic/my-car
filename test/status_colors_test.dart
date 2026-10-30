import 'package:flutter_test/flutter_test.dart';
import 'package:my_car/core/utils/status_colors.dart';

void main() {
  test('Gecikmiş, yaklaşan ve geçerli tarih durumları ayrılır', () {
    expect(StatusColors.forDays(-1), RecordStatus.overdue);
    expect(StatusColors.forDays(0), RecordStatus.attention);
    expect(StatusColors.forDays(30), RecordStatus.attention);
    expect(StatusColors.forDays(31), RecordStatus.valid);
  });
}
