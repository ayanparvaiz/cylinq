import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/fields_dialog.dart';
import '../../../core/widgets/page.dart';
import '../../../core/widgets/status_chip.dart';
import '../../session/session.dart';
import '../data/customers_repository.dart';
import 'customer_form.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerProvider(id));
    final admin = ref.watch(sessionProvider.select((s) => s.isAdmin));
    final text = Theme.of(context).textTheme;

    return AsyncView(
      value: customer,
      data: (c) {
        if (c == null) {
          return const Scaffold(body: EmptyState(icon: Icons.person_off_outlined, title: 'Customer not found'));
        }
        return PageScaffold(
          title: c.name,
          maxWidth: 860,
          actions: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showCustomerForm(context, existing: c),
            ),
            if (admin)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Delete ${c.name}?',
                    message: 'Their past sales stay in the reports.',
                  );
                  if (!ok || !context.mounted) return;
                  await ref.read(customersRepositoryProvider).delete(c);
                  if (context.mounted) context.go(AppRoutes.customers);
                },
              ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('${AppRoutes.deliver}?customer=${c.id}'),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Deliver here'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 14,
                    children: [
                      _Fact('Area', c.areaName.isEmpty ? '—' : c.areaName),
                      _Fact('Phone', c.phone.isEmpty ? '—' : c.phone),
                      _Fact('Holding now', '${c.holding} cylinders'),
                      _Fact('Bought', '${c.totalQty} refills'),
                      _Fact('Last delivery', dateTime(c.lastSaleAt)),
                      _Fact(
                        'Location',
                        c.geo == null
                            ? 'Not saved'
                            : '${c.geo!.latitude.toStringAsFixed(5)}, ${c.geo!.longitude.toStringAsFixed(5)}',
                      ),
                      if (c.address.isNotEmpty) _Fact('Address', c.address),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Our cylinders here'),
              AsyncView(
                value: ref.watch(customerCylindersProvider(c.id)),
                data: (list) => list.isEmpty
                    ? const Card(child: EmptyState(icon: Icons.propane_tank_outlined, title: 'None right now'))
                    : Card(
                        child: Column(
                          children: [
                            for (final cyl in list)
                              ListTile(
                                title: Text(cyl.serial, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${cyl.typeName} · delivered ${ago(cyl.lastEventAt)}'),
                                trailing: StatusChip(cyl, dense: true),
                                onTap: () => context.push(AppRoutes.cylinder(cyl.serial)),
                              ),
                          ],
                        ),
                      ),
              ),
              const SectionTitle('Recent deliveries'),
              AsyncView(
                value: ref.watch(customerSalesProvider(c.id)),
                data: (sales) => sales.isEmpty
                    ? const Card(child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No deliveries yet'))
                    : Card(
                        child: Column(
                          children: [
                            for (final s in sales)
                              ListTile(
                                leading: const Icon(Icons.receipt_long_outlined),
                                title: Text('${s.given.length} given · ${s.taken.length} empty back'),
                                subtitle: Text('${dateTime(s.at)} · ${s.byName} · ${s.payment.label}'),
                                trailing: Text(rupees(s.amount), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 2),
          Text(value, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
