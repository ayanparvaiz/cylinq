import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';
import '../../../core/models/cylinder.dart';
import '../../../core/models/cylinder_status.dart';
import '../../../core/models/movement.dart';
import '../../session/session.dart';

/// Filters on the cylinders page, each a cheap equality query.
enum CylinderFilter {
  all('All'),
  godownFull('Full at godown'),
  godownEmpty('Empty at godown'),
  vehicle('In vehicles'),
  customer('With customers'),
  lost('Lost'),
  retired('Retired');

  const CylinderFilter(this.label);
  final String label;

  Query<Json> apply(Query<Json> q) => switch (this) {
    CylinderFilter.all => q,
    CylinderFilter.godownFull => q.where('status', isEqualTo: 'godown').where('filled', isEqualTo: true),
    CylinderFilter.godownEmpty => q.where('status', isEqualTo: 'godown').where('filled', isEqualTo: false),
    CylinderFilter.vehicle => q.where('status', isEqualTo: CylinderStatus.vehicle.name),
    CylinderFilter.customer => q.where('status', isEqualTo: CylinderStatus.customer.name),
    CylinderFilter.lost => q.where('status', isEqualTo: CylinderStatus.lost.name),
    CylinderFilter.retired => q.where('status', isEqualTo: CylinderStatus.retired.name),
  };
}

/// Page size for lists. Every listed doc is a billed read, so lists stay short
/// and the dashboard uses count queries instead.
const cylinderListLimit = 300;

final cylinderListProvider = StreamProvider.autoDispose.family<List<Cylinder>, CylinderFilter>((ref, filter) {
  final refs = ref.watch(orgRefsProvider);
  return filter
      .apply(refs.cylinders)
      .limit(cylinderListLimit)
      .snapshots()
      .map((s) => s.docs.map(Cylinder.fromDoc).toList());
});

final cylinderProvider = StreamProvider.autoDispose.family<Cylinder?, String>((ref, serial) {
  final refs = ref.watch(orgRefsProvider);
  return refs.cylinders.doc(serial).snapshots().map((d) => d.exists ? Cylinder.fromDoc(d) : null);
});

final cylinderHistoryProvider = StreamProvider.autoDispose.family<List<CylinderEvent>, String>((ref, serial) {
  final refs = ref.watch(orgRefsProvider);
  return refs.events
      .where('cylinderId', isEqualTo: serial)
      .orderBy('at', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(CylinderEvent.fromDoc).toList());
});

/// What the signed-in staff member is carrying right now.
final myVehicleProvider = StreamProvider.autoDispose<List<Cylinder>>((ref) {
  final refs = ref.watch(orgRefsProvider);
  final uid = ref.watch(sessionProvider.select((s) => s.uid));
  return refs.cylinders
      .where('holderId', isEqualTo: uid)
      .where('status', isEqualTo: CylinderStatus.vehicle.name)
      .snapshots()
      .map((s) => s.docs.map(Cylinder.fromDoc).toList());
});

/// Cylinders with a customer, longest first. Old ones may be lost or kept
/// as stock by a shop; either way someone should go and ask.
final overdueCylindersProvider = StreamProvider.autoDispose.family<List<Cylinder>, int>((ref, days) {
  final refs = ref.watch(orgRefsProvider);
  final cutoff = DateTime.now().subtract(Duration(days: days));
  return refs.cylinders
      .where('status', isEqualTo: CylinderStatus.customer.name)
      .where('lastEventAt', isLessThan: Timestamp.fromDate(cutoff))
      .orderBy('lastEventAt')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Cylinder.fromDoc).toList());
});

/// Count per filter, via aggregation queries: one billed read per 1,000
/// cylinders counted, instead of one per cylinder.
final cylinderCountsProvider = FutureProvider.autoDispose<Map<CylinderFilter, int>>((ref) async {
  final refs = ref.watch(orgRefsProvider);
  final entries = await Future.wait([
    for (final f in CylinderFilter.values)
      f.apply(refs.cylinders).count().get().then((s) => MapEntry(f, s.count ?? 0)),
  ]);
  return Map.fromEntries(entries);
});

final cylindersRepositoryProvider = Provider<CylindersRepository>(
  (ref) => CylindersRepository(ref.watch(orgRefsProvider)),
);

class CylindersRepository {
  CylindersRepository(this._refs);

  final OrgRefs _refs;

  Future<Cylinder?> fetch(String serial) async {
    final doc = await _refs.cylinders.doc(serial).get();
    return doc.exists ? Cylinder.fromDoc(doc) : null;
  }
}
