import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/cylinder.dart';
import '../../../core/models/cylinder_status.dart';
import '../../../core/models/movement.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/qr_payload.dart';
import '../../../core/widgets/page.dart';
import '../../../core/widgets/status_chip.dart';
import '../../labels/pdf/label_pdf.dart';
import '../../labels/presentation/label_preview_screen.dart';
import '../../moves/data/moves_repository.dart';
import '../../session/session.dart';
import '../data/cylinders_repository.dart';

class CylinderDetailScreen extends ConsumerWidget {
  const CylinderDetailScreen({super.key, required this.serial});

  final String serial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return AsyncView(
      value: ref.watch(cylinderProvider(serial)),
      data: (c) {
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.help_outline,
              title: '$serial not found',
              message: 'It is not registered in ${session.org.name}.',
            ),
          );
        }
        return PageScaffold(
          title: c.serial,
          maxWidth: 860,
          actions: [
            if (session.isAdmin)
              PopupMenuButton<String>(
                tooltip: 'Admin actions',
                onSelected: (action) => _adminAction(context, ref, c, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'print', child: Text('Print label')),
                  if (c.status != CylinderStatus.lost) const PopupMenuItem(value: 'lost', child: Text('Mark lost')),
                  if (c.status == CylinderStatus.lost) const PopupMenuItem(value: 'found', child: Text('Found: back at godown')),
                  const PopupMenuItem(value: 'fix', child: Text('Correct state')),
                  if (c.status != CylinderStatus.retired) const PopupMenuItem(value: 'retire', child: Text('Retire (damaged / expired)')),
                ],
              ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(
                          data: QrPayload.forCylinder(session.orgId, c.serial),
                          size: 132,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.serial, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(c.typeName),
                          const SizedBox(height: 10),
                          StatusChip(c),
                          const SizedBox(height: 10),
                          if (c.holderName != null) Text('With ${c.holderName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Since ${since(c.lastEventAt)} · ${dateTime(c.lastEventAt)}'),
                          if (c.lastGeo != null)
                            Text('Last seen at ${c.lastGeo!.latitude.toStringAsFixed(5)}, ${c.lastGeo!.longitude.toStringAsFixed(5)}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('History'),
              AsyncView(
                value: ref.watch(cylinderHistoryProvider(c.serial)),
                data: (events) => Card(
                  child: Column(
                    children: [
                      for (final (i, e) in events.indexed) ...[
                        if (i > 0) const Divider(height: 1, indent: 64),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: e.to.color(filled: e.filled).withValues(alpha: 0.14),
                            foregroundColor: e.to.color(filled: e.filled),
                            child: Icon(e.type.icon, size: 20),
                          ),
                          title: Text(e.customerName == null ? e.type.label : '${e.type.label} · ${e.customerName}'),
                          subtitle: Text('${dateTime(e.at)} · ${e.byName}${e.geo == null ? '' : ' · GPS'}'),
                        ),
                      ],
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

  Future<void> _adminAction(BuildContext context, WidgetRef ref, Cylinder c, String action) async {
    final moves = ref.read(movesRepositoryProvider);
    switch (action) {
      case 'print':
        await LabelPreviewScreen.open(
          context,
          org: ref.read(sessionProvider).org,
          items: [LabelItem(serial: c.serial, typeName: c.typeName)],
          layout: LabelLayout.thermal,
        );
      case 'lost':
        await moves.adjust(c, type: MoveType.lost, to: CylinderStatus.lost, filled: c.filled);
      case 'found':
        await moves.adjust(c, type: MoveType.found, to: CylinderStatus.godown, filled: false);
      case 'retire':
        await moves.adjust(c, type: MoveType.retire, to: CylinderStatus.retired, filled: false);
      case 'fix':
        final picked = await showDialog<(CylinderStatus, bool)>(
          context: context,
          builder: (_) => _CorrectStateDialog(current: c),
        );
        if (picked != null) {
          await moves.adjust(c, type: MoveType.adjust, to: picked.$1, filled: picked.$2, note: 'Manual correction');
        }
    }
  }
}

class _CorrectStateDialog extends StatefulWidget {
  const _CorrectStateDialog({required this.current});
  final Cylinder current;

  @override
  State<_CorrectStateDialog> createState() => _CorrectStateDialogState();
}

class _CorrectStateDialogState extends State<_CorrectStateDialog> {
  late CylinderStatus _status = widget.current.status;
  late bool _filled = widget.current.filled;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correct state'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<CylinderStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Where is it?'),
            items: [for (final s in CylinderStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (s) => setState(() => _status = s!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Full'),
            value: _filled,
            onChanged: (v) => setState(() => _filled = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, (_status, _filled)), child: const Text('Save')),
      ],
    );
  }
}
