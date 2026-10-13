import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/cylinder.dart';
import '../../../core/models/cylinder_status.dart';
import '../../../core/models/sales.dart';
import '../../session/session.dart';

/// All customers, searched on the device. A gas agency has hundreds to a few
/// thousand, and the offline cache means they are read once, not per search.
final customersProvider = StreamProvider<List<Customer>>((ref) {
  final refs = ref.watch(orgRefsProvider);
  return refs.customers.orderBy('name').limit(3000).snapshots().map((s) => s.docs.map(Customer.fromDoc).toList());
});

final customerProvider = StreamProvider.autoDispose.family<Customer?, String>((ref, id) {
  final refs = ref.watch(orgRefsProvider);
  return refs.customers.doc(id).snapshots().map((d) => d.exists ? Customer.fromDoc(d) : null);
});

final customerSalesProvider = StreamProvider.autoDispose.family<List<Sale>, String>((ref, id) {
  final refs = ref.watch(orgRefsProvider);
  return refs.sales
      .where('customerId', isEqualTo: id)
      .orderBy('at', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(Sale.fromDoc).toList());
});

final customerCylindersProvider = StreamProvider.autoDispose.family<List<Cylinder>, String>((ref, id) {
  final refs = ref.watch(orgRefsProvider);
  return refs.cylinders
      .where('holderId', isEqualTo: id)
      .where('status', isEqualTo: CylinderStatus.customer.name)
      .snapshots()
      .map((s) => s.docs.map(Cylinder.fromDoc).toList());
});

final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(ref.watch(orgRefsProvider), ref.watch(sessionProvider)),
);

class CustomersRepository {
  CustomersRepository(this._refs, this._session);

  final OrgRefs _refs;
  final Session _session;

  Future<Customer> create({
    required String name,
    required String phone,
    required String address,
    Area? area,
    GeoPoint? geo,
  }) async {
    final doc = _refs.customers.doc();
    final now = FieldValue.serverTimestamp();
    final data = {
      'name': name.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'areaId': area?.id,
      'areaName': area?.name ?? '',
      'geo': geo,
      'holding': 0,
      'totalQty': 0,
      'createdBy': _session.uid,
      'createdAt': now,
      'updatedAt': now,
    };
    // Not awaited past a short wait: offline, the write is queued and the
    // delivery can go ahead with the new customer straight away.
    await doc.set(data).timeout(const Duration(seconds: 8), onTimeout: () {});
    return Customer(
      id: doc.id,
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      areaId: area?.id,
      areaName: area?.name ?? '',
      geo: geo,
    );
  }

  Future<void> update(
    Customer c, {
    required String name,
    required String phone,
    required String address,
    Area? area,
    GeoPoint? geo,
  }) => _refs.customers.doc(c.id).update({
    'name': name.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'areaId': area?.id,
    'areaName': area?.name ?? '',
    'geo': ?geo,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(Customer c) => _refs.customers.doc(c.id).delete();
}
