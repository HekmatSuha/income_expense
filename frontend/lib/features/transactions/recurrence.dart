import 'package:intl/intl.dart';

enum RecurrenceFrequency { daily, weekly, monthly }

extension RecurrenceFrequencyX on RecurrenceFrequency {
  String get storageValue => name;

  String get label {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
    }
  }

  DateTime addTo(DateTime date) {
    switch (this) {
      case RecurrenceFrequency.daily:
        return date.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return date.add(const Duration(days: 7));
      case RecurrenceFrequency.monthly:
        final nextMonthAnchor = DateTime(
          date.year,
          date.month + 1,
          1,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );
        final daysInTargetMonth = DateTime(nextMonthAnchor.year, nextMonthAnchor.month + 1, 0).day;
        final clampedDay = date.day.clamp(1, daysInTargetMonth).toInt();
        return DateTime(
          nextMonthAnchor.year,
          nextMonthAnchor.month,
          clampedDay,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );
    }
  }
}

extension RecurrenceFrequencyParsing on RecurrenceFrequency {
  static RecurrenceFrequency? fromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    return RecurrenceFrequency.values.firstWhere(
      (freq) => freq.storageValue == value,
      orElse: () => RecurrenceFrequency.monthly,
    );
  }

  static String formatDate(DateTime date) {
    final formatter = DateFormat.yMMMMd().add_jm();
    return formatter.format(date);
  }
}
