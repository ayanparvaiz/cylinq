import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/widgets/page.dart';
import '../../cylinders/data/cylinders_repository.dart';
import '../../moves/data/moves_repository.dart';
import '../../moves/move_rules.dart';
import '../../session/session.dart';
import '../scan_resolver.dart';
import 'scanned_list.dart';
import 'scanner_panel.dart';

/// Godown and vehicle work: fill, load, return. Deliveries have their own
/// screen because they also need a customer and money.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, this.initialMode = ScanMode.lookup});

  /// Set from `/scan?mode=load` so a shortcut can open straight into a job.
  final ScanMode initialMode;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  static const _modes = [ScanMode.lookup, ScanMode.fill, ScanMode.load, ScanMode.returned];

  late ScanMode _mode = _modes.contains(widget.initialMode) ? widget.initialMode : ScanMode.lookup;
  final _items = <ScannedItem>[];
  bool _busy = false;

  Future<void> _onCode(String raw) async {
    final result = await resolveScan(
      raw,
      orgId: ref.read(sessionProvider).orgId,
      repo: ref.read(cylindersRepositoryProvider),
    );
    if (!mounted) return;
    switch (result) {
      case Rejected(:final reason):
        showMessage(context, reason);
      case Found(:final cylinder) when _mode == ScanMode.lookup:
        context.push(AppRoutes.cylinder(cylinder.serial));
      case Found(:final cylinder):
        if (_items.any((i) => i.cylinder.serial == cylinder.serial)) {
          return showMessage(context, '${cylinder.serial} is already in the list');
        }
        final check = checkMove(_mode, cylinder);
        if (!check.allowed) return showMessage(context, '${cylinder.serial}: ${check.warning}');
        setState(() => _items.add(ScannedItem(cylinder, check)));
    }
  }

  void _setMode(ScanMode mode) {
    setState(() {
      _mode = mode;
      // Re-check what is already scanned against the new job.
      final kept = [
        for (final i in _items)
          if (checkMove(mode, i.cylinder) case final c when c.allowed) ScannedItem(i.cylinder, c),
      ];
      _items
        ..clear()
        ..addAll(mode == ScanMode.lookup ? const [] : kept);
    });
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final n = _items.length;
      final synced = await ref.read(movesRepositoryProvider).moveAll([for (final i in _items) i.cylinder], _mode);
      if (!mounted) return;
      setState(_items.clear);
      showMessage(
        context,
        synced
            ? '$n cylinder${n == 1 ? '' : 's'} · ${_mode.moveType.label.toLowerCase()}'
            : 'Saved on this phone. It will sync when you are back online.',
      );
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final vehicle = ref.watch(myVehicleProvider).value ?? const [];
    final full = vehicle.where((c) => c.filled).length;

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(18, 6, 12, 6),
            iconColor: Colors.white,
            textColor: Colors.white,
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Deliver to a customer', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              'In my vehicle: $full full · ${vehicle.length - full} empty',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => context.push(AppRoutes.deliver),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _modes)
              ChoiceChip(
                label: Text(m.label),
                selected: _mode == m,
                onSelected: (_) => _setMode(m),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(_mode.hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        ScannerPanel(onCode: _onCode, height: wide ? 380 : 250),
      ],
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mode != ScanMode.lookup) ...[
          ScannedList(
            items: _items,
            onRemove: (i) => setState(() => _items.remove(i)),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _items.isEmpty || _busy ? null : _confirm,
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_mode.moveType.icon),
            label: Text('${_mode.label} ${_items.length} cylinder${_items.length == 1 ? '' : 's'}'),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Scan any label to open that cylinder.')),
          ),
      ],
    );

    return PageScaffold(
      title: 'Scan',
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: controls),
                const SizedBox(width: 20),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: list)),
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [controls, const SizedBox(height: 14), list]),
    );
  }
}
