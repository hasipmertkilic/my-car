import 'package:intl/intl.dart';

abstract final class Formatters {
  static String preciseMoney(num value) => NumberFormat.currency(
    locale: 'tr',
    symbol: '₺',
    decimalDigits: 2,
  ).format(value);
  static String decimal(num value) => NumberFormat('0.00', 'tr').format(value);
  static String number(num value) =>
      NumberFormat.decimalPattern('tr').format(value);
  static String money(num value) => NumberFormat.currency(
    locale: 'tr',
    symbol: '₺',
    decimalDigits: 0,
  ).format(value);
  static String date(DateTime value) =>
      DateFormat('d MMM yyyy', 'tr').format(value);
}
