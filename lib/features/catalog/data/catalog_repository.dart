import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';
import '../../../core/models/catalog.dart';
import '../../session/session.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(orgRefsProvider)),
);

final typesProvider = StreamProvider<List<CylinderType>>((ref) {
  final refs = ref.watch(orgRefsProvider);
  return refs.types
      .orderBy('weightKg')
      .snapshots()
      .map((s) => s.docs.map(CylinderType.fromDoc).toList());
});

final areasProvider = StreamProvider<List<Area>>((ref) {
  final refs = ref.watch(orgRefsProvider);
  return refs.areas.orderBy('name').snapshots().map((s) => s.docs.map(Area.fromDoc).toList());
});

/// id → name lookups for the dashboard and lists.
final areaNamesProvider = Provider<Map<String, String>>((ref) {
  final areas = ref.watch(areasProvider).value ?? const [];
  return {for (final a in areas) a.id: a.name};
});

class CatalogRepository {
  CatalogRepository(this._refs);

  final OrgRefs _refs;

  Future<void> saveType({String? id, required String name, required double weightKg, required num price}) {
    final doc = id == null ? _refs.types.doc() : _refs.types.doc(id);
    return doc.set({
      'name': name.trim(),
      'weightKg': weightKg,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteType(String id) => _refs.types.doc(id).delete();

  Future<void> saveArea({String? id, required String name, String pincode = ''}) {
    final doc = id == null ? _refs.areas.doc() : _refs.areas.doc(id);
    return doc.set({
      'name': name.trim(),
      'pincode': pincode.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteArea(String id) => _refs.areas.doc(id).delete();

  Future<void> updateBusiness({required String name, required String phone, required String address}) =>
      _refs.org.update({'name': name.trim(), 'phone': phone.trim(), 'address': address.trim()});
}
