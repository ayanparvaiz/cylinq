import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/cylinder.dart';
import '../../../core/models/cylinder_status.dart';
import '../../../core/models/movement.dart';
import '../../../core/models/sales.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geohash.dart';
import '../../session/session.dart';
import '../move_rules.dart';

final movesRepositoryProvider = Provider<MovesRepository>(
  (ref) => MovesRepository(ref.watch(orgRefsProvider), ref.watch(sessionProvider)),
);

/// Writes cylinder moves. Each move is an immutable event plus the cylinder's
/// new state in the same batch, which is exactly what the rules demand.
class MovesRepository {
  MovesRepository(this._refs, this._session);

  final OrgRefs _refs;
  final Session _session;

  /// Rules may read at most 20 docs per batch and each cylinder update reads
  /// its event, so large scans are split. The tests prove 16 pass.
  static const perBatch = 15;

  /// Most cylinders one delivery visit can carry (given + taken).
  static const maxPerDelivery = 16;

  /// Fill, load or return a list of scanned cylinders.
  /// Returns false when saved offline and still waiting to sync.
  Future<bool> moveAll(List<Cylinder> cylinders, ScanMode mode, {GeoPoint? geo}) async {
    final day = dayKey(DateTime.now());
    var synced = true;
    for (var i = 0; i < cylinders.length; i += perBatch) {
      final batch = _refs.db.batch();
      for (final c in cylinders.skip(i).take(perBatch)) {
        final (to, filled) = mode.target(c);
        final inVehicle = to == CylinderStatus.vehicle;
        _addMove(
          batch,
          c,
          type: mode.moveType,
          to: to,
          filled: filled,
          holderId: inVehicle ? _session.uid : null,
          holderName: inVehicle ? _session.member.name : null,
          geo: geo,
          day: day,
        );
      }
      synced = await _commit(batch) && synced;
    }
    return synced;
  }

  /// One delivery visit: full cylinders [given], empties [taken], money in.
  ///
  /// The sale and the day's totals are written only when something was sold,
  /// so a visit that only picks up empties does not count as a sale.
  Future<bool> deliver({
    required Customer customer,
    required List<Cylinder> given,
    required List<Cylinder> taken,
    required num amount,
    required PaymentMode payment,
    GeoPoint? geo,
  }) {
    assert(given.length + taken.length <= maxPerDelivery);
    final day = dayKey(DateTime.now());
    final batch = _refs.db.batch();
    final now = FieldValue.serverTimestamp();
    final areaId = customer.areaId;
    String? saleId;

    if (given.isNotEmpty) {
      final sale = _refs.sales.doc();
      saleId = sale.id;
      final cell = geo == null ? null : Geohash.encode(geo.latitude, geo.longitude);
      batch.set(sale, {
        'customerId': customer.id,
        'customerName': customer.name,
        'areaId': areaId,
        'areaName': customer.areaName,
        'given': [for (final c in given) c.serial],
        'taken': [for (final c in taken) c.serial],
        'qty': given.length,
        'amount': amount,
        'payment': payment.name,
        'geo': geo,
        'cell': cell,
        'by': _session.uid,
        'byName': _session.member.name,
        'at': now,
        'day': day,
      });
      final areaKey = areaId ?? '_none';
      batch.set(
        _refs.daily.doc(day),
        {
          'day': day,
          'sales': FieldValue.increment(1),
          'qty': FieldValue.increment(given.length),
          'amount': FieldValue.increment(amount),
          'areas': {
            areaKey: {
              'sales': FieldValue.increment(1),
              'qty': FieldValue.increment(given.length),
              'amount': FieldValue.increment(amount),
            },
          },
          'cells': {?cell: FieldValue.increment(given.length)},
          'lastSaleId': sale.id,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    for (final c in given) {
      _addMove(
        batch,
        c,
        type: MoveType.deliver,
        to: CylinderStatus.customer,
        filled: true,
        holderId: customer.id,
        holderName: customer.name,
        areaId: areaId,
        customer: customer,
        saleId: saleId,
        geo: geo,
        day: day,
      );
    }
    for (final c in taken) {
      _addMove(
        batch,
        c,
        type: MoveType.collect,
        to: CylinderStatus.vehicle,
        filled: false,
        holderId: _session.uid,
        holderName: _session.member.name,
        customer: customer,
        saleId: saleId,
        geo: geo,
        day: day,
      );
    }

    // Only empties that were on this customer's books reduce what they hold.
    final returnedHere = taken.where((c) => c.holderId == customer.id).length;
    batch.update(_refs.customers.doc(customer.id), {
      'holding': FieldValue.increment(given.length - returnedHere),
      'totalQty': FieldValue.increment(given.length),
      if (given.isNotEmpty) 'lastSaleAt': now,
      if (customer.geo == null && geo != null) 'geo': geo,
      'updatedAt': now,
    });
    return _commit(batch);
  }

  /// Admin corrections: lost, found, retired, or a manual fix.
  Future<bool> adjust(
    Cylinder c, {
    required MoveType type,
    required CylinderStatus to,
    required bool filled,
    String? note,
  }) {
    assert(type.adminOnly);
    final batch = _refs.db.batch();
    _addMove(
      batch,
      c,
      type: type,
      to: to,
      filled: filled,
      holderId: to == c.status ? c.holderId : null,
      holderName: to == c.status ? c.holderName : null,
      areaId: to == c.status ? c.areaId : null,
      note: note,
      day: dayKey(DateTime.now()),
    );
    return _commit(batch);
  }

  void _addMove(
    WriteBatch batch,
    Cylinder c, {
    required MoveType type,
    required CylinderStatus to,
    required bool filled,
    required String day,
    String? holderId,
    String? holderName,
    String? areaId,
    Customer? customer,
    String? saleId,
    GeoPoint? geo,
    String? note,
  }) {
    final event = _refs.events.doc();
    final now = FieldValue.serverTimestamp();
    batch.set(event, {
      'type': type.wire,
      'cylinderId': c.serial,
      'typeId': c.typeId,
      'from': c.status.name,
      'to': to.name,
      'filled': filled,
      'by': _session.uid,
      'byName': _session.member.name,
      if (customer != null) 'customerId': customer.id,
      if (customer != null) 'customerName': customer.name,
      'areaId': ?areaId,
      'saleId': ?saleId,
      'geo': ?geo,
      if (note != null && note.isNotEmpty) 'note': note,
      'at': now,
      'day': day,
    });
    batch.update(_refs.cylinders.doc(c.serial), {
      'status': to.name,
      'filled': filled,
      'holderId': holderId,
      'holderName': holderName,
      'areaId': areaId,
      'lastGeo': ?geo,
      'lastEventId': event.id,
      'lastEventAt': now,
    });
  }

  /// Waits for the server, but not forever. Offline, Firestore keeps the batch
  /// queued on the phone and sends it when signal returns.
  static Future<bool> _commit(WriteBatch batch) async {
    try {
      await batch.commit().timeout(const Duration(seconds: 10));
      return true;
    } on TimeoutException {
      return false;
    }
  }
}
