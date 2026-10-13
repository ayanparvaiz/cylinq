import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/device_location.dart';
import '../../../core/models/customer.dart';
import '../../../core/widgets/page.dart';
import '../../catalog/data/catalog_repository.dart';
import '../data/customers_repository.dart';

/// Add or edit a customer in a bottom sheet. Returns the saved customer.
Future<Customer?> showCustomerForm(BuildContext context, {Customer? existing}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CustomerForm(existing: existing),
    ),
  );
}

class _CustomerForm extends ConsumerStatefulWidget {
  const _CustomerForm({this.existing});
  final Customer? existing;

  @override
  ConsumerState<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<_CustomerForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _address = TextEditingController(text: widget.existing?.address);
  late String? _areaId = widget.existing?.areaId;
  GeoPoint? _geo;
  bool _locating = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final geo = await DeviceLocation.current();
    if (!mounted) return;
    setState(() {
      _geo = geo;
      _locating = false;
    });
    if (geo == null) showMessage(context, 'Could not get location. Is GPS on?');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(customersRepositoryProvider);
    final areas = ref.read(areasProvider).value ?? const [];
    final area = areas.where((a) => a.id == _areaId).firstOrNull;
    try {
      final existing = widget.existing;
      final Customer saved;
      if (existing == null) {
        saved = await repo.create(name: _name.text, phone: _phone.text, address: _address.text, area: area, geo: _geo);
      } else {
        await repo.update(existing, name: _name.text, phone: _phone.text, address: _address.text, area: area, geo: _geo);
        saved = existing;
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(areasProvider).value ?? const [];
    final hasGeo = _geo != null || widget.existing?.geo != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New customer' : 'Edit customer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name or shop name'),
              validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Required',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: areas.any((a) => a.id == _areaId) ? _areaId : null,
              decoration: InputDecoration(
                labelText: 'Area',
                helperText: areas.isEmpty ? 'The owner adds areas in Settings' : null,
              ),
              items: [for (final a in areas) DropdownMenuItem(value: a.id, child: Text(a.name))],
              onChanged: (v) => setState(() => _areaId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address / landmark'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _locating ? null : _locate,
              icon: _locating
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(hasGeo ? Icons.check_circle : Icons.my_location),
              label: Text(hasGeo ? 'Location saved · tap to update' : 'I am at the customer: save location'),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save customer')),
          ],
        ),
      ),
    );
  }
}
