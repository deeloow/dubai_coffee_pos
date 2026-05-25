// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';

class Formatters {
  static final _pesoFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static String peso(double amount) => _pesoFormat.format(amount);

  static String date(DateTime dt) =>
      DateFormat('MMM d, yyyy', 'en_PH').format(dt);

  static String time(DateTime dt) =>
      DateFormat('h:mm a', 'en_PH').format(dt);

  static String dateTime(DateTime dt) =>
      DateFormat('MMM d, yyyy h:mm a', 'en_PH').format(dt);

  static String shortDate(DateTime dt) =>
      DateFormat('MM/dd/yy', 'en_PH').format(dt);

  static String orderNumber(int num) => '#${num.toString().padLeft(3, '0')}';
}
