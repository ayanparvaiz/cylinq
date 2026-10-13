import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/device_location.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/sales.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/page.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../customers/data/customers_repository.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../cylinders/data/cylinders_repository.dart';
import '../../moves/data/moves_repository.dart';
import '../../moves/move_rules.dart';
import '../../scan/presentation/scanned_list.dart';
import '../../scan/presentation/scanner_panel.dart';
import '../../scan/scan_resolver.dart';
import '../../session/session.dart';
import 'customer_picker.dart';

/// One visit to one customer: hand over full cylinders, take empties back,
/// note the money. Saved as a single batch with the phone's location.
class DeliverScreen extends ConsumerStatefulWidget {
  const DeliverScreen({super.key, this.customerId});

  final String? customerId;

  @override
  ConsumerState<DeliverScreen> createState() => _DeliverScreenState();
}

class _DeliverScreenState extends ConsumerState<DeliverScreen> {
  Customer? _customer;
  ScanMode _side = ScanMode.give;
  final _given = <ScannedItem>[];
  final _taken = <ScannedItem>[];
  final _amount = TextEditingController();
  bool _amountEdited = false;
  PaymentMode _payment = PaymentMode.cash;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _total => _given.length + _taken.length;

  /// Sum of refill prices for what was handed over, until someone types over it.
  void _recalcAmount() {
    if (_amountEdited) return;
    final types = ref.read(typesProvider).value ?? const [];
    final price = {for (final t in types) t.id: t.price};
    final sum = _given.fold<num>(0, (s, i) => s + (price[i.cylinder.typeId] ?? 0));
    _amount.text = sum == 0
        ? ''
        : sum == sum.roundToDouble()
        ? '${sum.round()}'
        : sum.toStringAsFixed(2);
  }

  Future<void> _onCode(String raw) async {
    if (_total >= MovesRepository.maxPerDelivery) {
      return showMessage(context, 'At most ${MovesRepository.maxPerDelivery} cylinders per delivery');
    }
    final result = await resolveScan(
      raw,
      orgId: ref.read(sessionProvider).orgId,
      repo: ref.read(cylindersRepositoryProvider),
    );
    if (!mounted) return;
    switch (result) {
      case Rejected(:final reason):
        showMessage(context, reason);
      case Found(:final cylinder):
        if ([..._given, ..._taken].any((i) => i.cylinder.serial == cylinder.serial)) {
          return showMessage(context, '${cylinder.serial} is already in this delivery');
        }
        final check = checkMove(_side, cylinder);
        if (!check.allowed) return showMessage(context, '${cylinder.serial}: ${check.warning}');
        setState(() {
          (_side == ScanMode.give ? _given : _taken).add(ScannedItem(cylinder, check));
          _recalcAmount();
        });
    }
  }

  Future<void> _submit() async {
    final customer = _customer;
    if (customer == null) return showMessage(context, 'Choose the customer first');
    if (_total == 0) return showMessage(context, 'Scan at least one cylinder');
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount < 0) return showMessage(context, 'Amount cannot be negative');

    setState(() => _busy = true);
    try {
      final geo = await DeviceLocation.current();
      final synced = await ref.read(movesRepositoryProvider).deliver(
        customer: customer,
        given: [for (final i in _given) i.cylinder],
        taken: [for (final i in _taken) i.cylinder],
        amount: _given.isEmpty ? 0 : amount,
        payment: _payment,
        geo: geo,
      );
      if (!mounted) return;
      showMessage(
        context,
        synced
            ? 'Delivered to ${customer.name}${geo == null ? ' (no GPS)' : ''}'
            : 'Saved on this phone. It will sync when you are back online.',
      );
      // Leave straight away so a second tap cannot save the same visit twice.
      // Opened from a bookmark or QR link there is nothing to pop back to.
      context.canPop() ? context.pop() : context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep prices loaded, and price anything scanned before they arrived.
    ref.listen(typesProvider, (_, next) {
      if (next.hasValue) setState(_recalcAmount);
    });
    // Pre-select the customer when opened from their page.
    if (_customer == null && widget.customerId != null) {
      final all = ref.watch(customersProvider).value ?? const [];
      _customer = all.where((c) => c.id == widget.customerId).firstOrNull;
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final text = Theme.of(context).textTheme;
    final customer = _customer;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (customer == null)
          OutlinedButton.icon(
            onPressed: () async {
              final c = await showCustomerPicker(context);
              if (c != null) setState(() => _customer = c);
            },
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Choose customer'),
          )
        else
          CustomerTile(
            customer: customer,
            onTap: () async {
              final c = await showCustomerPicker(context);
              if (c != null) setState(() => _customer = c);
            },
            trailing: const Icon(Icons.swap_horiz),
          ),
        const SizedBox(height: 14),
        SegmentedButton<ScanMode>(
          segments: [
            ButtonSegment(value: ScanMode.give, icon: const Icon(Icons.upload), label: Text('Give full (${_given.length})')),
            ButtonSegment(value: ScanMode.take, icon: const Icon(Icons.download), label: Text('Take empty (${_taken.length})')),
          ],
          selected: {_side},
          onSelectionChanged: (s) => setState(() => _side = s.first),
        ),
        const SizedBox(height: 12),
        ScannerPanel(
          onCode: _onCode,
          height: wide ? 360 : 240,
          hint: _side == ScanMode.give ? 'Scanning: full given' : 'Scanning: empty taken',
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Full given', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ScannedList(
          items: _given,
          emptyText: 'Scan the full cylinders you hand over',
          onRemove: (i) => setState(() {
            _given.remove(i);
            _recalcAmount();
          }),
        ),
        const SizedBox(height: 10),
        Text('Empty taken back', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        ScannedList(
          items: _taken,
          emptyText: 'Switch to "Take empty" and scan the empties',
          onRemove: (i) => setState(() => _taken.remove(i)),
        ),
        const SizedBox(height: 14),
        if (_given.isNotEmpty) ...[
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', hintText: '0'),
            onChanged: (_) => setState(() => _amountEdited = true),
          ),
          const SizedBox(height: 12),
          SegmentedButton<PaymentMode>(
            segments: [for (final p in PaymentMode.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {_payment},
            onSelectionChanged: (s) => setState(() => _payment = s.first),
          ),
          const SizedBox(height: 14),
        ],
        FilledButton.icon(
          onPressed: _busy || customer == null || _total == 0 ? null : _submit,
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: Text(
            _given.isEmpty
                ? 'Save pickup'
                : 'Complete delivery · ${rupees(num.tryParse(_amount.text) ?? 0)}',
          ),
        ),
      ],
    );

    return PageScaffold(
      title: 'Delivery',
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 20),
                Expanded(child: right),
              ],
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]),
    );
  }
}
