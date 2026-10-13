import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

/// Email/password only: it is free on the Spark plan, unlike phone OTP.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.reload();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}

/// Human wording for the Firebase Auth errors people actually hit.
String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) return 'Something went wrong. Try again.';
  return switch (error.code) {
    'invalid-email' => 'That email address looks wrong.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' =>
      'Email or password is incorrect.',
    'email-already-in-use' => 'An account with this email already exists.',
    'weak-password' => 'Use at least 6 characters for the password.',
    'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
    'network-request-failed' => 'No internet connection.',
    _ => error.message ?? 'Sign-in failed (${error.code}).',
  };
}
