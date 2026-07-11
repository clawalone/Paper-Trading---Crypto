import 'package:intl/intl.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class CurrencyFormatters {
  static double usdToInr = 84.50; // Now mutable, will be updated by initExchangeRate()

  /// Fetches live exchange rate from free API
  static Future<void> initExchangeRate() async {
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['rates'] != null && data['rates']['INR'] != null) {
          usdToInr = (data['rates']['INR'] as num).toDouble();
        }
      }
    } catch (_) {
      // Fallback to default 84.50 if API fails or offline
    }
  }

  /// Returns just the currency symbol (e.g., $ or ₹)
  static String getSymbol(String? currencyCode) {
    if (currencyCode == 'USD') return '\$';
    return '₹';
  }

  /// Converts a base INR amount to the target currency amount
  static double convert(double baseAmountInr, String? currencyCode) {
    if (currencyCode == 'USD') return baseAmountInr / usdToInr;
    return baseAmountInr; 
  }

  /// Converts and formats a base INR amount to the target currency
  static String format(double baseAmountInr, String? currencyCode, {int decimalDigits = 2}) {
    final isUSD = currencyCode == 'USD';
    final amount = isUSD ? baseAmountInr / usdToInr : baseAmountInr;
    
    final formatter = NumberFormat.currency(
      locale: isUSD ? 'en_US' : 'en_IN',
      symbol: isUSD ? '\$' : '₹',
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  /// Converts and formats a base INR amount to the target currency in a compact form (e.g., $1.2K)
  static String formatCompact(double baseAmountInr, String? currencyCode) {
    final isUSD = currencyCode == 'USD';
    final amount = isUSD ? baseAmountInr / usdToInr : baseAmountInr;
    
    final formatter = NumberFormat.compactCurrency(
      locale: isUSD ? 'en_US' : 'en_IN',
      symbol: isUSD ? '\$' : '₹',
    );
    return formatter.format(amount);
  }

  /// Returns a full currency formatter with decimal digits (e.g., $1,234.56 or ₹1,234.56)
  static NumberFormat getFormatter(String? currencyCode, {int decimalDigits = 2}) {
    if (currencyCode == 'USD') {
      return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: decimalDigits);
    }
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: decimalDigits);
  }

  /// Returns a compact currency formatter (e.g., $1.2K or ₹1.2K)
  static NumberFormat getCompactFormatter(String? currencyCode) {
    if (currencyCode == 'USD') {
      return NumberFormat.compactCurrency(locale: 'en_US', symbol: '\$');
    }
    return NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹');
  }
}

class AppCurrencyFormatter {
  final String? currencyCode;
  final int decimalDigits;
  late final NumberFormat _formatter;

  AppCurrencyFormatter(this.currencyCode, {this.decimalDigits = 2}) {
    final isUSD = currencyCode == 'USD';
    _formatter = NumberFormat.currency(
      locale: isUSD ? 'en_US' : 'en_IN',
      symbol: isUSD ? '\$' : '₹',
      decimalDigits: decimalDigits,
    );
  }

  String format(num? baseAmountInr) {
    final val = baseAmountInr ?? 0;
    final isUSD = currencyCode == 'USD';
    final amount = isUSD ? val / CurrencyFormatters.usdToInr : val;
    return _formatter.format(amount);
  }
}

class AppCompactCurrencyFormatter {
  final String? currencyCode;
  late final NumberFormat _formatter;

  AppCompactCurrencyFormatter(this.currencyCode) {
    final isUSD = currencyCode == 'USD';
    _formatter = NumberFormat.compactCurrency(
      locale: isUSD ? 'en_US' : 'en_IN',
      symbol: isUSD ? '\$' : '₹',
    );
  }

  String format(num? baseAmountInr) {
    final val = baseAmountInr ?? 0;
    final isUSD = currencyCode == 'USD';
    final amount = isUSD ? val / CurrencyFormatters.usdToInr : val;
    return _formatter.format(amount);
  }
}
