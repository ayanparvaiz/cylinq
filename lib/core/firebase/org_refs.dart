import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

/// Collection references for one business, so paths are spelled in one place.
class OrgRefs {
  OrgRefs(this.orgId, [FirebaseFirestore? db]) : db = db ?? FirebaseFirestore.instance;

  final String orgId;
  final FirebaseFirestore db;

  DocumentReference<Json> get org => db.doc('orgs/$orgId');
  CollectionReference<Json> get members => org.collection('members');
  CollectionReference<Json> get types => org.collection('types');
  CollectionReference<Json> get areas => org.collection('areas');
  CollectionReference<Json> get customers => org.collection('customers');
  CollectionReference<Json> get cylinders => org.collection('cylinders');
  CollectionReference<Json> get events => org.collection('events');
  CollectionReference<Json> get sales => org.collection('sales');
  CollectionReference<Json> get daily => org.collection('daily');

  static DocumentReference<Json> account(String uid, [FirebaseFirestore? db]) =>
      (db ?? FirebaseFirestore.instance).doc('accounts/$uid');
}
