import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs (no `#/`), so a QR label's https://cylinq.web.app/c/... link
  // opens that cylinder when scanned with an ordinary phone camera.
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Cache on device so staff keep scanning in godowns and villages with weak
  // signal; writes sync when the phone is back online. Also saves reads.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024,
  );
  runApp(
    ProviderScope(
      // Riverpod retries failed providers forever by default. Two quick retries
      // ride out a dropped connection; after that it is a real error (most
      // often a permission one) and retrying would only burn free-tier reads.
      retry: (attempt, error) => attempt >= 2 ? null : Duration(seconds: 1 << attempt),
      child: const CylinqApp(),
    ),
  );
}
