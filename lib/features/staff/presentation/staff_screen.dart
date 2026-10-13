import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/member.dart';
import '../../../core/widgets/fields_dialog.dart';
import '../../../core/widgets/page.dart';
import '../../auth/data/auth_repository.dart';
import '../../session/session.dart';
import '../data/staff_repository.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final repo = ref.read(staffRepositoryProvider);

    return PageScaffold(
      title: 'Staff',
      maxWidth: 760,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, repo),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add staff'),
      ),
      body: AsyncView(
        value: ref.watch(membersProvider),
        data: (members) => Card(
          child: Column(
            children: [
              for (final (i, m) in members.indexed) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
                  title: Text(m.name),
                  subtitle: Text([m.role.label, if (m.email.isNotEmpty) m.email, if (m.phone.isNotEmpty) m.phone].join(' · ')),
                  trailing: m.uid == session.org.ownerUid
                      ? const Chip(label: Text('Owner'))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<Role>(
                              tooltip: 'Change role',
                              icon: const Icon(Icons.manage_accounts_outlined),
                              onSelected: (r) => repo.setRole(m, r),
                              itemBuilder: (_) => [
                                for (final r in Role.values)
                                  CheckedPopupMenuItem(value: r, checked: r == m.role, child: Text(r.label)),
                              ],
                            ),
                            Switch(
                              value: m.active,
                              onChanged: (v) => repo.setActive(m, v),
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, StaffRepository repo) async {
    final password = _tempPassword();
    final v = await showFieldsDialog(context, title: 'Add staff', confirm: 'Create login', fields: [
      const FieldSpec('Name'),
      const FieldSpec('Email (used to sign in)', keyboard: TextInputType.emailAddress),
      const FieldSpec('Phone', keyboard: TextInputType.phone, required: false),
      FieldSpec('Password', initial: password, validator: (v) => v.length >= 6 ? null : 'At least 6 characters'),
    ]);
    if (v == null || !context.mounted) return;
    try {
      await repo.addStaff(name: v[0], email: v[1], phone: v[2], password: v[3], role: Role.staff);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Login created'),
          content: SelectableText('Share this with ${v[0]}:\n\nEmail: ${v[1]}\nPassword: ${v[3]}'),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: 'CylinQ login\nEmail: ${v[1]}\nPassword: ${v[3]}')),
              child: const Text('Copy'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, authErrorMessage(e));
    }
  }

  /// Easy to read aloud over the phone: no 0/O or 1/l.
  static String _tempPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
