import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/widgets/brand_mark.dart';
import '../session/session.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _home = _Dest(AppRoutes.home, 'Home', Icons.space_dashboard_outlined, Icons.space_dashboard);
const _scan = _Dest(AppRoutes.scan, 'Scan', Icons.qr_code_scanner, Icons.qr_code_scanner);
const _cylinders = _Dest(AppRoutes.cylinders, 'Cylinders', Icons.propane_tank_outlined, Icons.propane_tank);
const _labels = _Dest(AppRoutes.labels, 'QR labels', Icons.qr_code_2_outlined, Icons.qr_code_2);
const _customers = _Dest(AppRoutes.customers, 'Customers', Icons.people_alt_outlined, Icons.people_alt);
const _staff = _Dest(AppRoutes.staff, 'Staff', Icons.badge_outlined, Icons.badge);
const _settings = _Dest(AppRoutes.settings, 'Settings', Icons.settings_outlined, Icons.settings);

/// Signed-in frame. Wide screens (the owner's browser) get a navy sidebar with
/// everything; phones get a bottom bar with the five things used on the road.
/// Labels and Staff stay reachable on phones from the Settings page.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;

    final dests = switch ((session.isAdmin, wide)) {
      (true, true) => const [_home, _scan, _cylinders, _labels, _customers, _staff, _settings],
      (true, false) => const [_home, _scan, _cylinders, _customers, _settings],
      (false, _) => const [_home, _scan, _cylinders, _customers, _settings],
    };
    final index = _indexFor(location, dests);

    if (!wide) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(dests[i].path),
          destinations: [
            for (final d in dests)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1200,
            minExtendedWidth: 220,
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(dests[i].path),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: BrandMark(
                size: 34,
                onDark: true,
                showName: MediaQuery.sizeOf(context).width >= 1200,
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Tooltip(
                    message: '${session.member.name} · ${session.org.name}',
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      foregroundColor: Colors.white,
                      child: Text(_initials(session.member.name)),
                    ),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  static int _indexFor(String location, List<_Dest> dests) {
    for (var i = dests.length - 1; i >= 0; i--) {
      final p = dests[i].path;
      if (p == AppRoutes.home ? location == p : location.startsWith(p)) return i;
    }
    // Pages reached from Settings on a phone (labels, staff) keep Settings lit.
    return dests.length - 1;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
