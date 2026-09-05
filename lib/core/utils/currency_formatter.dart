import 'package:intl/intl.dart';

/// Formats currency amounts using the session's currency code (e.g. ₹125.00).
class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {required String currencyCode}) {
    final symbol = _symbolFor(currencyCode);
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  static String _symbolFor(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$currencyCode ';
    }
  }
}
