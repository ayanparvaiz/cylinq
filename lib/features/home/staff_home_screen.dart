import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page.dart';
import '../cylinders/data/cylinders_repository.dart';
import '../dashboard/data/stats_repository.dart';
import '../dashboard/widgets/stat_tile.dart';
import '../session/session.dart';

/// A delivery person's day: what is on the vehicle, what was delivered.
class StaffHomeScreen extends ConsumerWidget {
  const StaffHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final vehicle = ref.watch(myVehicleProvider).value ?? const [];
    final full = vehicle.where((c) => c.filled).length;
    final sales = ref.watch(myTodaySalesProvider);
    final text = Theme.of(context).textTheme;

    return PageScaffold(
      title: 'Hi, ${session.member.name.split(' ').first}',
      maxWidth: 720,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(session.org.name, style: text.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.deliver),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Start a delivery'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.scan),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan: load, fill or return'),
          ),
          const SectionTitle('On my vehicle'),
          TileGrid(
            minWidth: 140,
            children: [
              StatTile(label: 'Full', value: '$full'),
              StatTile(label: 'Empty', value: '${vehicle.length - full}'),
            ],
          ),
          const SectionTitle('Today'),
          AsyncView(
            value: sales,
            data: (list) {
              final qty = list.fold(0, (s, x) => s + x.given.length);
              final amount = list.fold<num>(0, (s, x) => s + x.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TileGrid(
                    minWidth: 140,
                    children: [
                      StatTile(label: 'Delivered', value: '$qty', caption: '${list.length} visits'),
                      StatTile(label: 'Collected', value: rupees(amount)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final s in list)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(s.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${s.given.length} full · ${s.taken.length} empty · ${dateTime(s.at)}'),
                        trailing: Text(rupees(s.amount), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
