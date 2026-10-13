import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/dashboard_screen.dart';
import '../session/session.dart';
import 'staff_home_screen.dart';

/// Landing page after sign-in. Admins get the dashboard, staff their day.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(sessionProvider.select((s) => s.isAdmin));
    return admin ? const DashboardScreen() : const StaffHomeScreen();
  }
}
