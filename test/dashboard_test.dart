import 'package:cylinq/core/models/sales.dart';
import 'package:cylinq/core/utils/formatters.dart';
import 'package:cylinq/features/dashboard/data/stats_repository.dart';
import 'package:cylinq/features/dashboard/widgets/area_bars.dart';
import 'package:cylinq/features/dashboard/widgets/daily_trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = dayKey(DateTime.now());
  final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));

  final docs = [
    DailyStats(
      day: yesterday,
      sales: 2,
      qty: 3,
      amount: 2700,
      areas: const {'a1': AreaTotal(sales: 2, qty: 3, amount: 2700)},
      cells: const {'tun4p1': 3},
    ),
    DailyStats(
      day: today,
      sales: 1,
      qty: 2,
      amount: 1800,
      areas: const {'a1': AreaTotal(sales: 1, qty: 1, amount: 900), 'a2': AreaTotal(sales: 1, qty: 1, amount: 900)},
      cells: const {'tun4p1': 1, 'tun4p2': 1},
    ),
  ];

  test('folds days into totals and zero-fills the gaps', () {
    final s = StatsSummary.fold(StatsRange.week, docs);
    expect(s.days.length, 7);
    expect(s.days.last.day, today);
    expect(s.days.first.qty, 0);
    expect(s.qty, 5);
    expect(s.sales, 3);
    expect(s.amount, 4500);
    expect(s.areas['a1']!.qty, 4);
    expect(s.areas['a2']!.amount, 900);
    expect(s.cells['tun4p1'], 4);
  });

  testWidgets('area bars and trend chart lay out side by side', (tester) async {
    final s = StatsSummary.fold(StatsRange.month, docs);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AreaBars(areas: s.areas, names: const {'a1': 'Salt Lake', 'a2': 'Behala'})),
                Expanded(child: DailyTrendChart(days: s.days)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Salt Lake'), findsOneWidget);
    expect(find.text('Behala'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long tails fold into Other', (tester) async {
    final areas = {for (var i = 0; i < 14; i++) 'a$i': AreaTotal(sales: 1, qty: 14 - i, amount: 100)};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AreaBars(areas: areas, names: const {}))));
    expect(find.text('Other areas'), findsOneWidget);
  });
}
