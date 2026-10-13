import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/org_refs.dart';
import '../../core/models/member.dart';
import '../../core/models/org.dart';
import '../auth/data/auth_repository.dart';

final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

final accountProvider = StreamProvider<Account?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(null);
  // Skip snapshots that exist only in the local cache. Right after "Create
  // business" the account shows up locally before the server has the batch,
  // and listening to the membership then would be refused by the rules.
  return OrgRefs.account(user.uid)
      .snapshots(includeMetadataChanges: true)
      .where((doc) => !doc.metadata.hasPendingWrites)
      .map((doc) => doc.exists ? Account.fromDoc(doc) : null)
      .distinct((a, b) => a?.orgId == b?.orgId && a?.role == b?.role);
});

final _memberProvider = StreamProvider<Member?>((ref) {
  final user = ref.watch(authUserProvider).value;
  final account = ref.watch(accountProvider).value;
  if (user == null || account == null) return Stream.value(null);
  return OrgRefs(account.orgId).members.doc(user.uid).snapshots().map(
    (doc) => doc.exists ? Member.fromDoc(doc) : null,
  );
});

final _orgProvider = StreamProvider<Org?>((ref) {
  final account = ref.watch(accountProvider).value;
  final member = ref.watch(_memberProvider).value;
  // Only an active member may read the business doc, so wait for membership.
  if (account == null || member == null || !member.active) return Stream.value(null);
  return OrgRefs(account.orgId).org.snapshots().map(
    (doc) => doc.exists ? Org.fromDoc(doc) : null,
  );
});

/// Where the signed-in person stands. The router redirects on this.
sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class SignedOut extends SessionState {
  const SignedOut();
}

/// Signed in, but not part of any business yet: an owner who must set one up,
/// or a staff member whose owner has not added them.
class NeedsBusiness extends SessionState {
  const NeedsBusiness(this.user);
  final User user;
}

/// Part of a business, but switched off by the admin.
class NoAccess extends SessionState {
  const NoAccess(this.user);
  final User user;
}

class Ready extends SessionState {
  const Ready(this.session);
  final Session session;
}

class Session {
  const Session({required this.user, required this.member, required this.org});

  final User user;
  final Member member;
  final Org org;

  String get uid => user.uid;
  String get orgId => org.id;
  bool get isAdmin => member.isAdmin;
}

final sessionStateProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authUserProvider);
  if (!auth.hasValue) return const SessionLoading();
  final user = auth.value;
  if (user == null) return const SignedOut();

  final account = ref.watch(accountProvider);
  if (account.hasError) return NoAccess(user);
  if (!account.hasValue) return const SessionLoading();
  if (account.value == null) return NeedsBusiness(user);

  final member = ref.watch(_memberProvider);
  // Rules hide the member doc from inactive members, which surfaces as an error.
  if (member.hasError) return NoAccess(user);
  if (!member.hasValue) return const SessionLoading();
  final m = member.value;
  if (m == null || !m.active) return NoAccess(user);

  final org = ref.watch(_orgProvider);
  if (org.hasError) return NoAccess(user);
  final o = org.value;
  if (o == null) return const SessionLoading();
  return Ready(Session(user: user, member: m, org: o));
});

/// The session inside the signed-in shell. Only read it below the shell, where
/// the router guarantees [Ready].
final sessionProvider = NotifierProvider<_SessionNotifier, Session>(_SessionNotifier.new);

class _SessionNotifier extends Notifier<Session> {
  Session? _last;

  @override
  Session build() {
    final state = ref.watch(sessionStateProvider);
    if (state is Ready) return _last = state.session;
    if (state is SignedOut) _last = null;
    // Mid-transition (a listener reconnecting): keep the last good session so
    // pages in the shell do not crash in the frame before the router moves on.
    return _last ?? (throw StateError('No business session'));
  }
}

final orgRefsProvider = Provider<OrgRefs>(
  (ref) => OrgRefs(ref.watch(sessionProvider.select((s) => s.orgId))),
);
