import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/cylinder.dart';
import '../../../core/models/org.dart';
import '../../../core/utils/formatters.dart';
import '../../session/session.dart';
import '../pdf/label_pdf.dart';

final labelsRepositoryProvider = Provider<LabelsRepository>(
  (ref) => LabelsRepository(ref.watch(orgRefsProvider), ref.watch(sessionProvider)),
);

class LabelsRepository {
  LabelsRepository(this._refs, this._session);

  final OrgRefs _refs;
  final Session _session;

  /// Most labels made in one go. Each cylinder costs two writes (cylinder +
  /// register event) and a transaction allows 500.
  static const maxBatch = 200;

  /// Reserves the next [count] serials and registers a cylinder for each.
  /// A transaction on `nextSerial` means two admins printing at once can never
  /// get the same numbers.
  Future<List<LabelItem>> generate({
    required CylinderType type,
    required int count,
    required bool filled,
  }) {
    assert(count > 0 && count <= maxBatch);
    return _refs.db.runTransaction((tx) async {
      final org = Org.fromDoc(await tx.get(_refs.org));
      final now = FieldValue.serverTimestamp();
      final today = dayKey(DateTime.now());
      final items = <LabelItem>[];
      for (var i = 0; i < count; i++) {
        final serial = org.serialFor(org.nextSerial + i);
        final event = _refs.events.doc();
        tx.set(event, {
          'type': 'register',
          'cylinderId': serial,
          'typeId': type.id,
          'to': 'godown',
          'filled': filled,
          'by': _session.uid,
          'byName': _session.member.name,
          'at': now,
          'day': today,
        });
        tx.set(_refs.cylinders.doc(serial), {
          'serial': serial,
          'typeId': type.id,
          'typeName': type.name,
          'status': 'godown',
          'filled': filled,
          'holderId': null,
          'holderName': null,
          'areaId': null,
          'lastGeo': null,
          'lastEventId': event.id,
          'lastEventAt': now,
          'createdAt': now,
        });
        items.add(LabelItem(serial: serial, typeName: type.name));
      }
      tx.update(_refs.org, {'nextSerial': org.nextSerial + count});
      return items;
    });
  }

  /// Existing cylinders from serial number [from] to [to], for reprinting.
  Future<List<LabelItem>> range(int from, int to) async {
    final org = _session.org;
    final snap = await _refs.cylinders
        .orderBy(FieldPath.documentId)
        .startAt([org.serialFor(from)])
        .endAt([org.serialFor(to)])
        .get();
    return snap.docs
        .map(Cylinder.fromDoc)
        .map((c) => LabelItem(serial: c.serial, typeName: c.typeName))
        .toList();
  }
}
