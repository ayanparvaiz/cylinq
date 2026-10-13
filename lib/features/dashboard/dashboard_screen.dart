import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page.dart';
import '../catalog/data/catalog_repository.dart';
import '../cylinders/data/cylinders_repository.dart';
import '../cylinders/presentation/cylinders_screen.dart';
import '../session/session.dart';
import 'data/stats_repository.dart';
import 'widgets/area_bars.dart';
import 'widgets/daily_trend_chart.dart';
import 'widgets/delivery_map.dart';
import 'widgets/stat_tile.dart';

/// The owner's view: what sold, where, and where every cylinder is now.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  StatsRange _range = StatsRange.month;
  static const _overdueDays = 30;

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(sessionProvider.select((s) => s.org));
    final stats = ref.watch(statsProvider(_range));
    final counts = ref.watch(cylinderCountsProvider).value;
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return PageScaffold(
      title: org.name,
      maxWidth: 1240,
      actions: [
        IconButton(
          tooltip: 'Refresh cylinder counts',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(cylinderCountsProvider),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filters sit in one row above everything they affect.
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<StatsRange>(
              showSelectedIcon: false,
              segments: [for (final r in StatsRange.values) ButtonSegment(value: r, label: Text(r.label))],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
          const SizedBox(height: 16),
          AsyncView(
            value: stats,
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TileGrid(
                  minWidth: 200,
                  children: [
                    StatTile(label: 'Revenue', value: rupees(s.amount), caption: _range.label, hero: true),
                    StatTile(label: 'Cylinders sold', value: count(s.qty), caption: _range.label),
                    StatTile(label: 'Deliveries', value: count(s.sales), caption: _range.label),
                    StatTile(
                      label: 'Average per delivery',
                      value: s.sales == 0 ? '—' : rupees((s.amount / s.sales).round()),
                      caption: s.sales == 0 ? null : '${(s.qty / s.sales).toStringAsFixed(1)} cylinders',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Panels(
                  wide: wide,
                  left: _Panel(
                    title: 'Cylinders sold by area',
                    child: s.areas.isEmpty
                        ? const EmptyState(icon: Icons.bar_chart, title: 'No sales in this period')
                        : AreaBars(areas: s.areas, names: ref.watch(areaNamesProvider)),
                  ),
                  right: _Panel(
                    title: 'Cylinders sold per day',
                    child: _range == StatsRange.today
                        ? const EmptyState(icon: Icons.show_chart, title: 'Pick 7 days or more to see the trend')
                        : DailyTrendChart(days: s.days),
                  ),
                ),
                _Panel(
                  title: 'Where deliveries happened',
                  subtitle: 'Each circle is about 1 km across. Bigger and darker means more cylinders.',
                  child: s.cells.isEmpty
                      ? const EmptyState(
                          icon: Icons.map_outlined,
                          title: 'No GPS-tagged deliveries yet',
                          message: 'Deliveries saved with location on show up here.',
                        )
                      : DeliveryMap(cells: s.cells),
                ),
              ],
            ),
          ),
          const SectionTitle('Where cylinders are now'),
          TileGrid(
            minWidth: 150,
            children: [
              for (final (filter, icon, color) in const [
                (CylinderFilter.godownFull, Icons.warehouse_outlined, AppColors.full),
                (CylinderFilter.godownEmpty, Icons.warehouse_outlined, AppColors.empty),
                (CylinderFilter.vehicle, Icons.local_shipping_outlined, AppColors.vehicle),
                (CylinderFilter.customer, Icons.storefront_outlined, AppColors.customer),
                (CylinderFilter.lost, Icons.report_gmailerrorred_outlined, AppColors.lost),
              ])
                StatTile(
                  label: filter.label,
                  value: counts == null ? '…' : count(counts[filter] ?? 0),
                  icon: icon,
                  iconColor: color,
                  onTap: () => context.go(AppRoutes.cylinders),
                ),
            ],
          ),
          SectionTitle(
            'With a customer for $_overdueDays+ days',
            trailing: Text('Go and ask about these', style: Theme.of(context).textTheme.bodySmall),
          ),
          AsyncView(
            value: ref.watch(overdueCylindersProvider(_overdueDays)),
            data: (list) => list.isEmpty
                ? const Card(child: EmptyState(icon: Icons.verified_outlined, title: 'Nothing overdue'))
                : Column(
                    children: [
                      for (final c in list.take(20))
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: CylinderTile(c)),
                      if (list.length > 20) Text('…and ${list.length - 20} more'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Panels extends StatelessWidget {
  const _Panels({required this.wide, required this.left, required this.right});

  final bool wide;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!wide) return Column(children: [left, right]);
    // No IntrinsicHeight: the bars and chart lay out with LayoutBuilder.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodySmall),
              ],
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
