import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/customer.dart';
import '../../../core/widgets/page.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/presentation/customer_form.dart';
import '../../customers/presentation/customers_screen.dart';

Future<Customer?> showCustomerPicker(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.88, child: _Picker()),
  );
}

class _Picker extends ConsumerStatefulWidget {
  const _Picker();

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customer'),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final created = await showCustomerForm(context);
                  if (created != null && context.mounted) Navigator.pop(context, created);
                },
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView(
              value: ref.watch(customersProvider),
              data: (all) {
                final list = all.where((c) => c.matches(_query)).toList();
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.person_search_outlined, title: 'No customer found', message: 'Tap New to add one.');
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => CustomerTile(
                    customer: list[i],
                    onTap: () => Navigator.pop(context, list[i]),
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
