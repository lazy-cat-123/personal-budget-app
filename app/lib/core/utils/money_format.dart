import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'THB ',
  decimalDigits: 2,
);

String formatMoney(num value) => _moneyFormat.format(value);
