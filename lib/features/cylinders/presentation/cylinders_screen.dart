import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/cylinder.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/qr_payload.dart';
import '../../../core/widgets/page.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/cylinders_repository.dart';

class CylindersScreen extends ConsumerStatefulWidget {
  const CylindersScreen({super.key});

  @override
  ConsumerState<CylindersScreen> createState() => _CylindersScreenState();
}

class _CylindersScreenState extends ConsumerState<CylindersScreen> {
  CylinderFilter _filter = CylinderFilter.all;

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(cylinderCountsProvider).value;
    return PageScaffold(
      title: 'Cylinders',
      scroll: false,
      actions: [
        IconButton(
          tooltip: 'Refresh counts',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(cylinderCountsProvider),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Open by serial, e.g. GS-00042'),
            onSubmitted: (v) {
              final code = QrPayload.parse(v);
              if (code != null) context.push(AppRoutes.cylinder(code.serial));
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in CylinderFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(counts == null ? f.label : '${f.label} · ${count(counts[f] ?? 0)}'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncView(
              value: ref.watch(cylinderListProvider(_filter)),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.propane_tank_outlined,
                      title: 'No cylinders here',
                      message: 'Create QR labels to register cylinders.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: list.length + (list.length == cylinderListLimit ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => i == list.length
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Showing the first $cylinderListLimit. Search by serial for others.', textAlign: TextAlign.center),
                            )
                          : CylinderTile(list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class CylinderTile extends StatelessWidget {
  const CylinderTile(this.cylinder, {super.key});

  final Cylinder cylinder;

  @override
  Widget build(BuildContext context) {
    final c = cylinder;
    return Card(
      child: ListTile(
        onTap: () => context.push(AppRoutes.cylinder(c.serial)),
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        leading: Icon(Icons.propane_tank, color: c.status.color(filled: c.filled)),
        title: Text(c.serial, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([
          c.typeName,
          if (c.holderName != null) c.holderName!,
          ago(c.lastEventAt),
        ].join(' · ')),
        trailing: StatusChip(c, dense: true),
      ),
    );
  }
}
