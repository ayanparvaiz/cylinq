import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/sales.dart';
import '../../../core/utils/formatters.dart';
import '../../session/session.dart';

enum StatsRange {
  today(1, 'Today'),
  week(7, '7 days'),
  month(30, '30 days'),
  quarter(90, '90 days');

  const StatsRange(this.days, this.label);

  final int days;
  final String label;

  DateTime get start {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
  }
}

/// Totals for a date range, folded from the per-day docs.
class StatsSummary {
  const StatsSummary({
    required this.days,
    required this.sales,
    required this.qty,
    required this.amount,
    required this.areas,
    required this.cells,
  });

  /// One entry per calendar day in the range, zero-filled.
  final List<DailyStats> days;
  final int sales;
  final int qty;
  final num amount;
  final Map<String, AreaTotal> areas;
  final Map<String, int> cells;

  factory StatsSummary.fold(StatsRange range, List<DailyStats> docs) {
    final byDay = {for (final d in docs) d.day: d};
    final days = [
      for (var i = 0; i < range.days; i++)
        if (dayKey(range.start.add(Duration(days: i))) case final key) byDay[key] ?? DailyStats(day: key),
    ];
    final areas = <String, AreaTotal>{};
    final cells = <String, int>{};
    for (final d in docs) {
      d.areas.forEach((k, v) => areas[k] = (areas[k] ?? const AreaTotal()) + v);
      d.cells.forEach((k, v) => cells[k] = (cells[k] ?? 0) + v);
    }
    return StatsSummary(
      days: days,
      sales: docs.fold(0, (s, d) => s + d.sales),
      qty: docs.fold(0, (s, d) => s + d.qty),
      amount: docs.fold<num>(0, (s, d) => s + d.amount),
      areas: areas,
      cells: cells,
    );
  }
}

/// A month costs about 30 reads, however many deliveries happened.
final statsProvider = StreamProvider.autoDispose.family<StatsSummary, StatsRange>((ref, range) {
  final refs = ref.watch(orgRefsProvider);
  return refs.daily
      .orderBy(FieldPath.documentId)
      .startAt([dayKey(range.start)])
      .snapshots()
      .map((s) => StatsSummary.fold(range, s.docs.map(DailyStats.fromDoc).toList()));
});

/// The signed-in staff member's deliveries today.
final myTodaySalesProvider = StreamProvider.autoDispose<List<Sale>>((ref) {
  final refs = ref.watch(orgRefsProvider);
  final uid = ref.watch(sessionProvider.select((s) => s.uid));
  return refs.sales
      .where('by', isEqualTo: uid)
      .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(StatsRange.today.start))
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Sale.fromDoc).toList());
});
