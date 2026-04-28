import 'package:intl/intl.dart';

class DateUtils {
  /// Format date to readable string (e.g., "Jan 15, 2024")
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date and time (e.g., "Jan 15, 2024 - 2:30 PM")
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
  }

  /// Format time only (e.g., "2:30 PM")
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  /// Get relative date (e.g., "Today", "Yesterday", "3 days ago")
  static String getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
      final daysDiff = today.difference(dateOnly).inDays;
      return '$daysDiff days ago';
    } else {
      return formatDate(date);
    }
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if date is in the same month
  static bool isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }

  /// Get first day of month
  static DateTime getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get last day of month
  static DateTime getLastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Get first day of year
  static DateTime getFirstDayOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  /// Get last day of year
  static DateTime getLastDayOfYear(DateTime date) {
    return DateTime(date.year, 12, 31);
  }
}

class CurrencyUtils {
  /// Format amount as currency (e.g., "$1,234.56")
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat('$symbol#,##0.00');
    return formatter.format(amount);
  }

  /// Format amount with locale
  static String formatCurrencyWithLocale(
    double amount, {
    String locale = 'en_US',
    String? currencySymbol,
  }) {
    final formatter = NumberFormat.currency(locale: locale, symbol: currencySymbol);
    return formatter.format(amount);
  }

  /// Parse currency string to double (e.g., "$1,234.56" -> 1234.56)
  static double parseCurrency(String currencyString) {
    // Remove common currency symbols and non-numeric characters (except . and -)
    final cleanString = currencyString
        .replaceAll(RegExp(r'[^\d.-]'), '')
        .replaceAll(',', '');
    return double.tryParse(cleanString) ?? 0.0;
  }

  /// Format amount with abbreviation for large numbers (e.g., 1234 -> "1.2K")
  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(2);
  }
}

class ValidationUtils {
  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate amount (must be positive number)
  static bool isValidAmount(String amount) {
    try {
      final parsed = double.parse(amount);
      return parsed > 0;
    } catch (e) {
      return false;
    }
  }

  /// Validate title is not empty
  static bool isValidTitle(String title) {
    return title.trim().isNotEmpty;
  }
}
