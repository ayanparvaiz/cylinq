import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (_) => OnboardingRepository(FirebaseFirestore.instance),
);

class OnboardingRepository {
  OnboardingRepository(this._db);

  final FirebaseFirestore _db;

  /// Creates the business, the owner's admin membership and their account
  /// pointer in one batch. The rules only accept the three together, which is
  /// what stops anyone from making themselves admin of someone else's business.
  Future<void> createBusiness({
    required User owner,
    required String ownerName,
    required String businessName,
    required String labelPrefix,
    required String phone,
  }) async {
    final orgRef = _db.collection('orgs').doc();
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch()
      ..set(orgRef, {
        'name': businessName.trim(),
        'ownerUid': owner.uid,
        'phone': phone.trim(),
        'address': '',
        'labelPrefix': labelPrefix.trim().toUpperCase(),
        'nextSerial': 1,
        'createdAt': now,
      })
      ..set(orgRef.collection('members').doc(owner.uid), {
        'name': ownerName.trim(),
        'email': owner.email ?? '',
        'phone': phone.trim(),
        'role': 'admin',
        'active': true,
        'createdAt': now,
      })
      ..set(OrgRefs.account(owner.uid, _db), {
        'orgId': orgRef.id,
        'role': 'admin',
        'name': ownerName.trim(),
        'email': owner.email ?? '',
        'createdAt': now,
      });
    await batch.commit();

    // Common Indian LPG sizes to start with. Prices stay 0 until the owner
    // sets them in Settings, because they differ by city and change monthly.
    final types = orgRef.collection('types');
    final seed = _db.batch();
    for (final (name, kg) in const [
      ('14.2 kg Domestic', 14.2),
      ('19 kg Commercial', 19.0),
      ('5 kg FTL', 5.0),
    ]) {
      seed.set(types.doc(), {'name': name, 'weightKg': kg, 'price': 0, 'createdAt': now});
    }
    await seed.commit();
  }
}

/// `Shanti Gas Agency` → `SGA`. Used as the default label prefix.
String suggestPrefix(String businessName) {
  final letters = businessName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && RegExp('[A-Za-z]').hasMatch(w[0]))
      .map((w) => w[0].toUpperCase())
      .take(3)
      .join();
  return letters.isEmpty ? 'CQ' : letters;
}
