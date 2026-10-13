import 'package:intl/intl.dart';

final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _rupeesPaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _count = NumberFormat.decimalPattern('en_IN');
final _dayKey = DateFormat('yyyy-MM-dd');
final _dayLabel = DateFormat('d MMM');
final _dateTime = DateFormat('d MMM, h:mm a');

/// ₹1,23,456 — Indian digit grouping; paise only when there are any.
String rupees(num value) =>
    value == value.roundToDouble() ? _rupees.format(value) : _rupeesPaise.format(value);

String count(num value) => _count.format(value);

/// Daily stats doc id for a local date, e.g. `2026-10-13`.
String dayKey(DateTime date) => _dayKey.format(date);

DateTime parseDayKey(String key) => _dayKey.parse(key);

String dayLabel(DateTime date) => _dayLabel.format(date);

String dateTime(DateTime? date) => date == null ? '—' : _dateTime.format(date);

/// "today", "3 days", "2 months" — how long something has been somewhere.
String since(DateTime? date, {DateTime? now}) {
  if (date == null) return '—';
  final days = (now ?? DateTime.now()).difference(date).inDays;
  if (days < 1) return 'today';
  if (days < 60) return '$days day${days == 1 ? '' : 's'}';
  return '${days ~/ 30} months';
}
