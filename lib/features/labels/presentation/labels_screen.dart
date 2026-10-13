import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/widgets/page.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../session/session.dart';
import '../data/labels_repository.dart';
import '../pdf/label_pdf.dart';
import 'label_preview_screen.dart';

class LabelsScreen extends ConsumerStatefulWidget {
  const LabelsScreen({super.key});

  @override
  ConsumerState<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends ConsumerState<LabelsScreen> {
  String? _typeId;
  final _count = TextEditingController(text: '24');
  final _from = TextEditingController();
  final _to = TextEditingController();
  bool _filled = false;
  LabelLayout _layout = LabelLayout.a4Sheet;
  bool _busy = false;

  @override
  void dispose() {
    _count.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final types = ref.read(typesProvider).value ?? const <CylinderType>[];
    final type = types.where((t) => t.id == _typeId).firstOrNull;
    final count = int.tryParse(_count.text) ?? 0;
    if (type == null) return showMessage(context, 'Pick a cylinder type');
    if (count < 1 || count > LabelsRepository.maxBatch) {
      return showMessage(context, 'Make between 1 and ${LabelsRepository.maxBatch} labels at a time');
    }
    setState(() => _busy = true);
    try {
      final items = await ref.read(labelsRepositoryProvider).generate(type: type, count: count, filled: _filled);
      if (!mounted) return;
      await LabelPreviewScreen.open(context, org: ref.read(sessionProvider).org, items: items, layout: _layout);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not create labels: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reprint() async {
    final from = int.tryParse(_from.text), to = int.tryParse(_to.text) ?? int.tryParse(_from.text);
    if (from == null || to == null || to < from) return showMessage(context, 'Enter a valid number range');
    if (to - from >= 500) return showMessage(context, 'Reprint at most 500 at a time');
    setState(() => _busy = true);
    try {
      final items = await ref.read(labelsRepositoryProvider).range(from, to);
      if (!mounted) return;
      if (items.isEmpty) return showMessage(context, 'No cylinders in that range');
      await LabelPreviewScreen.open(context, org: ref.read(sessionProvider).org, items: items, layout: _layout);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not load cylinders: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(sessionProvider).org;
    final types = ref.watch(typesProvider).value ?? const [];
    // Default to the 14.2 kg domestic size, the one most agencies label first.
    _typeId ??= types.isEmpty ? null : (types.where((t) => t.weightKg == 14.2).firstOrNull ?? types.first).id;
    final count = int.tryParse(_count.text) ?? 0;
    final text = Theme.of(context).textTheme;

    return PageScaffold(
      title: 'QR labels',
      maxWidth: 760,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('New cylinders', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Each label gets the next serial and a cylinder record at the godown. '
                    'Stick one on each cylinder, near the valve guard.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    key: ValueKey(types.length),
                    initialValue: _typeId,
                    decoration: const InputDecoration(labelText: 'Cylinder type'),
                    items: [for (final t in types) DropdownMenuItem(value: t.id, child: Text(t.name))],
                    onChanged: (id) => setState(() => _typeId = id),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _count,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'How many',
                      helperText: count > 0
                          ? 'Serials ${org.serialFor(org.nextSerial)} to ${org.serialFor(org.nextSerial + count - 1)}'
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Empty now')),
                      ButtonSegment(value: true, label: Text('Full now')),
                    ],
                    selected: {_filled},
                    onSelectionChanged: (s) => setState(() => _filled = s.first),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _generate,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Create and print labels'),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Paper'),
          Card(
            child: RadioGroup<LabelLayout>(
              groupValue: _layout,
              onChanged: (l) => setState(() => _layout = l!),
              child: Column(
                children: [
                  for (final l in LabelLayout.values) RadioListTile(value: l, title: Text(l.label)),
                ],
              ),
            ),
          ),
          const SectionTitle('Reprint'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Label torn or faded? Print it again. Nothing is created.', style: text.bodyMedium),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _from,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(labelText: 'From number', prefixText: '${org.labelPrefix}-'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _to,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(labelText: 'To number', prefixText: '${org.labelPrefix}-'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _reprint,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Reprint'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
