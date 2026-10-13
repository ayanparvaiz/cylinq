import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/catalog.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/fields_dialog.dart';
import '../../core/widgets/page.dart';
import '../auth/data/auth_repository.dart';
import '../catalog/data/catalog_repository.dart';
import '../session/session.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final admin = session.isAdmin;
    final repo = ref.read(catalogRepositoryProvider);
    final org = session.org;

    return PageScaffold(
      title: 'Settings',
      maxWidth: 760,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
              leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
              title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                'Labels ${org.labelPrefix}-00001',
                if (org.phone.isNotEmpty) org.phone,
                if (org.address.isNotEmpty) org.address,
              ].join(' · ')),
              trailing: admin
                  ? IconButton(
                      tooltip: 'Edit business',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final v = await showFieldsDialog(context, title: 'Business', fields: [
                          FieldSpec('Name', initial: org.name),
                          FieldSpec('Phone', initial: org.phone, keyboard: TextInputType.phone, required: false),
                          FieldSpec('Address', initial: org.address, required: false),
                        ]);
                        if (v != null) await repo.updateBusiness(name: v[0], phone: v[1], address: v[2]);
                      },
                    )
                  : null,
            ),
          ),
          if (admin && MediaQuery.sizeOf(context).width < 900) ...[
            const SectionTitle('Manage'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.qr_code_2),
                    title: const Text('QR labels'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.labels),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Staff'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.staff),
                  ),
                ],
              ),
            ),
          ],
          SectionTitle(
            'Cylinder types',
            trailing: admin
                ? TextButton.icon(
                    onPressed: () => _editType(context, repo),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  )
                : null,
          ),
          AsyncView(
            value: ref.watch(typesProvider),
            data: (types) => Card(
              child: Column(
                children: [
                  for (final (i, t) in types.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.propane_tank_outlined),
                      title: Text(t.name),
                      subtitle: Text(t.price == 0 ? 'Price not set' : '${rupees(t.price)} per refill'),
                      trailing: admin ? const Icon(Icons.edit_outlined, size: 20) : null,
                      onTap: admin ? () => _editType(context, repo, t) : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SectionTitle(
            'Delivery areas',
            trailing: admin
                ? TextButton.icon(
                    onPressed: () => _editArea(context, repo),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  )
                : null,
          ),
          AsyncView(
            value: ref.watch(areasProvider),
            data: (areas) => areas.isEmpty
                ? const Card(
                    child: EmptyState(
                      icon: Icons.map_outlined,
                      title: 'No areas yet',
                      message: 'Add the localities you deliver to. Sales are grouped by area on the dashboard.',
                    ),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final (i, a) in areas.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(a.name),
                            subtitle: a.pincode.isEmpty ? null : Text(a.pincode),
                            trailing: admin ? const Icon(Icons.edit_outlined, size: 20) : null,
                            onTap: admin ? () => _editArea(context, repo, a) : null,
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SectionTitle('Account'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(session.member.name),
              subtitle: Text('${session.member.role.label} · ${session.user.email ?? ''}'),
              trailing: OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editType(BuildContext context, CatalogRepository repo, [CylinderType? t]) async {
    final v = await showFieldsDialog(context, title: t == null ? 'New cylinder type' : 'Edit type', fields: [
      FieldSpec('Name', initial: t?.name ?? '', hint: '14.2 kg Domestic'),
      FieldSpec('Weight (kg)', initial: t == null ? '' : '${t.weightKg}', keyboard: TextInputType.number, validator: numberValidator),
      FieldSpec('Refill price (₹)', initial: t == null ? '' : '${t.price}', keyboard: TextInputType.number, validator: numberValidator),
    ]);
    if (v == null) return;
    await repo.saveType(id: t?.id, name: v[0], weightKg: double.parse(v[1]), price: num.parse(v[2]));
  }

  Future<void> _editArea(BuildContext context, CatalogRepository repo, [Area? a]) async {
    final v = await showFieldsDialog(context, title: a == null ? 'New area' : 'Edit area', fields: [
      FieldSpec('Area name', initial: a?.name ?? '', hint: 'Salt Lake Sector V'),
      FieldSpec('Pincode', initial: a?.pincode ?? '', keyboard: TextInputType.number, required: false),
    ]);
    if (v == null) return;
    await repo.saveArea(id: a?.id, name: v[0], pincode: v[1]);
  }
}
