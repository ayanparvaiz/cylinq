import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/models/customer.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page.dart';
import '../data/customers_repository.dart';
import 'customer_form.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Customers',
      maxWidth: 860,
      scroll: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final c = await showCustomerForm(context);
          if (c != null && context.mounted) context.push(AppRoutes.customer(c.id));
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add customer'),
      ),
      body: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, phone or area',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView(
              value: ref.watch(customersProvider),
              data: (all) {
                final list = all.where((c) => c.matches(_query)).toList();
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.people_outline,
                    title: all.isEmpty ? 'No customers yet' : 'No match',
                    message: all.isEmpty ? 'Customers are added here or during a delivery.' : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => CustomerTile(
                    customer: list[i],
                    onTap: () => context.push(AppRoutes.customer(list[i].id)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerTile extends StatelessWidget {
  const CustomerTile({super.key, required this.customer, required this.onTap, this.trailing});

  final Customer customer;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.flame.withValues(alpha: 0.14),
          foregroundColor: AppColors.flameDeep,
          child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase()),
        ),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (c.areaName.isNotEmpty) c.areaName,
          if (c.phone.isNotEmpty) c.phone,
          if (c.lastSaleAt != null) 'last delivery ${ago(c.lastSaleAt)}',
        ].join(' · ')),
        trailing: trailing ??
            (c.holding > 0
                ? Tooltip(
                    message: 'Cylinders with this customer',
                    child: Chip(
                      avatar: const Icon(Icons.propane_tank_outlined, size: 16),
                      label: Text('${c.holding}'),
                    ),
                  )
                : null),
      ),
    );
  }
}
