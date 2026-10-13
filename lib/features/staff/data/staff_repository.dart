import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/org_refs.dart';
import '../../../core/models/member.dart';
import '../../../firebase_options.dart';
import '../../session/session.dart';

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.watch(orgRefsProvider)),
);

final membersProvider = StreamProvider<List<Member>>((ref) {
  final refs = ref.watch(orgRefsProvider);
  return refs.members.orderBy('name').snapshots().map((s) => s.docs.map(Member.fromDoc).toList());
});

class StaffRepository {
  StaffRepository(this._refs);

  final OrgRefs _refs;

  /// Creates a login for a staff member without signing the admin out.
  ///
  /// The usual way is the Admin SDK in a Cloud Function, which needs the paid
  /// plan. Instead a throwaway second Firebase app creates the user, so the
  /// admin's own session on the default app is untouched.
  Future<void> addStaff({
    required String name,
    required String email,
    required String password,
    required String phone,
    required Role role,
  }) async {
    final app = await Firebase.initializeApp(
      name: 'staff-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final String uid;
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user!.updateDisplayName(name.trim());
      uid = cred.user!.uid;
      await auth.signOut();
    } finally {
      await app.delete();
    }

    final now = FieldValue.serverTimestamp();
    await (_refs.db.batch()
          ..set(_refs.members.doc(uid), {
            'name': name.trim(),
            'email': email.trim(),
            'phone': phone.trim(),
            'role': role.name,
            'active': true,
            'createdAt': now,
          })
          ..set(OrgRefs.account(uid, _refs.db), {
            'orgId': _refs.orgId,
            'role': role.name,
            'name': name.trim(),
            'email': email.trim(),
            'createdAt': now,
          }))
        .commit();
  }

  Future<void> setActive(Member m, bool active) =>
      _refs.members.doc(m.uid).update({'active': active});

  Future<void> setRole(Member m, Role role) async {
    await (_refs.db.batch()
          ..update(_refs.members.doc(m.uid), {'role': role.name})
          ..update(OrgRefs.account(m.uid, _refs.db), {'role': role.name}))
        .commit();
  }
}
