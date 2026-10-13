import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session.dart';

/// Landing page after sign-in. Admins get the dashboard, staff their day.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(session.org.name)),
      body: Center(child: Text('Hello, ${session.member.name}')),
    );
  }
}
