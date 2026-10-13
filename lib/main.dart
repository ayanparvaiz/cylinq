import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Cache on device so staff keep scanning in godowns and villages with weak
  // signal; writes sync when the phone is back online. Also saves reads.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024,
  );
  runApp(
    ProviderScope(
      // Riverpod retries failed providers by default. A Firestore permission
      // error will not fix itself, and retrying it only burns free-tier reads.
      retry: (attempt, error) =>
          error is FirebaseException || attempt >= 3 ? null : Duration(seconds: 1 << attempt),
      child: const CylinqApp(),
    ),
  );
}
