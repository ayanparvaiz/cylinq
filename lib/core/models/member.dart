import 'package:cloud_firestore/cloud_firestore.dart';

enum Role {
  admin('Admin'),
  staff('Staff');

  const Role(this.label);
  final String label;

  static Role parse(Object? value) => value == 'admin' ? Role.admin : Role.staff;
}

/// A person who works for the business: the owner, a manager or a delivery boy.
class Member {
  const Member({
    required this.uid,
    required this.name,
    required this.role,
    required this.active,
    this.email = '',
    this.phone = '',
  });

  final String uid;
  final String name;
  final Role role;
  final bool active;
  final String email;
  final String phone;

  bool get isAdmin => role == Role.admin;

  factory Member.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Member(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      role: Role.parse(d['role']),
      active: d['active'] as bool? ?? false,
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
    );
  }
}

/// `accounts/{uid}`: tells a freshly signed-in user which business is theirs.
class Account {
  const Account({required this.uid, required this.orgId, required this.role});

  final String uid;
  final String orgId;
  final Role role;

  factory Account.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Account(
      uid: doc.id,
      orgId: d['orgId'] as String? ?? '',
      role: Role.parse(d['role']),
    );
  }
}
