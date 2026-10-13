import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/models/sales.dart';
import '../../../core/utils/formatters.dart';

/// Cylinders sold per area, largest first, as horizontal bars.
///
/// One series, so one hue and no legend: the card title names it. Every bar
/// carries its value at the tip, which doubles as the table view; hovering
/// (or long-pressing) a row adds revenue and delivery count.
class AreaBars extends StatelessWidget {
  const AreaBars({super.key, required this.areas, required this.names, this.maxRows = 10});

  final Map<String, AreaTotal> areas;
  final Map<String, String> names;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final rows = areas.entries.toList()..sort((a, b) => b.value.qty.compareTo(a.value.qty));
    // Past [maxRows] the tail folds into "Other" instead of a longer list.
    if (rows.length > maxRows) {
      final rest = rows.skip(maxRows - 1).fold(const AreaTotal(), (s, e) => s + e.value);
      rows
        ..removeRange(maxRows - 1, rows.length)
        ..add(MapEntry('_other', rest));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    final max = rows.first.value.qty == 0 ? 1 : rows.map((r) => r.value.qty).reduce((a, b) => a > b ? a : b);
    final text = Theme.of(context).textTheme;

    String nameOf(String id) => switch (id) {
      '_none' => 'No area set',
      '_other' => 'Other areas',
      _ => names[id] ?? 'Deleted area',
    };

    return Column(
      children: [
        for (final r in rows)
          Tooltip(
            message: '${nameOf(r.key)}: ${count(r.value.qty)} cylinders · ${rupees(r.value.amount)} · '
                '${count(r.value.sales)} deliveries',
            waitDuration: const Duration(milliseconds: 150),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(nameOf(r.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // Leave room at the tip for the value label.
                        final room = (box.maxWidth - 96).clamp(0.0, double.infinity);
                        final w = room * r.value.qty / max;
                        return Row(
                          children: [
                            Container(
                              width: w < 2 ? 2 : w,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: AppColors.flame,
                                // Square at the baseline, rounded at the data end.
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${count(r.value.qty)} · ${rupees(r.value.amount)}',
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: text.labelMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
