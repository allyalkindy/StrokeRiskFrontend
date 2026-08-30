import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui_kit.dart';

typedef _Tab = ({String path, IconData icon, String label});

const _doctorTabs = <_Tab>[
  (path: '/dashboard', icon: Icons.dashboard_rounded, label: 'Home'),
  (path: '/queue', icon: Icons.assignment_ind_outlined, label: 'Queue'),
  (path: '/patients', icon: Icons.people_alt_rounded, label: 'Patients'),
  (path: '/analytics', icon: Icons.insights_rounded, label: 'Reports'),
];

const _receptionTabs = <_Tab>[
  (path: '/patients', icon: Icons.people_alt_rounded, label: 'Patients'),
  (
    path: '/reception/assign',
    icon: Icons.person_add_alt_1_rounded,
    label: 'Assign'
  ),
];

const _labTabs = <_Tab>[
  (path: '/lab', icon: Icons.biotech_rounded, label: 'Lab Queue'),
];

const _adminTabs = <_Tab>[
  (path: '/admin/staff', icon: Icons.badge_rounded, label: 'Staff'),
  (path: '/admin', icon: Icons.dashboard_rounded, label: 'Dashboard'),
  (path: '/patients', icon: Icons.people_alt_rounded, label: 'Patients'),
];

List<_Tab> _tabsFor(StaffRole? role) => switch (role) {
      StaffRole.doctor => _doctorTabs,
      StaffRole.receptionist => _receptionTabs,
      StaffRole.labScientist => _labTabs,
      StaffRole.admin => _adminTabs,
      null => _doctorTabs,
    };

/// Responsive role-aware shell: NavigationRail on wide screens,
/// NavigationBar on narrow ones. Tabs are computed from the signed-in
/// staff member's role so the same chrome serves every role.
class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  /// Index of the tab whose path is the longest matching prefix of the
  /// current location — robust to nested routes and independent of tab
  /// display order.
  int _currentIndex(BuildContext context, List<_Tab> tabs) {
    final location = GoRouterState.of(context).uri.path;
    var bestIndex = 0;
    var bestLength = -1;
    for (var i = 0; i < tabs.length; i++) {
      final path = tabs[i].path;
      final matches = location == path || location.startsWith('$path/');
      if (matches && path.length > bestLength) {
        bestIndex = i;
        bestLength = path.length;
      }
    }
    return bestIndex;
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide =
        MediaQuery.sizeOf(context).width >= AppConstants.wideBreakpoint;
    final user = ref.watch(authProvider).currentUser;
    final tabs = _tabsFor(user?.role);
    final index = _currentIndex(context, tabs);

    if (!wide) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              if (user != null) ...[
                GradientAvatar(name: user.name, radius: 16),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  user?.name ?? AppConstants.appName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => _logout(context, ref),
            ),
          ],
        ),
        body: child,
        // NavigationBar asserts destinations.length >= 2 (Material 3
        // spec) — a role with a single tab (e.g. Lab Scientist, who only
        // has Lab Queue) has nothing to navigate between, so skip it
        // rather than crash.
        bottomNavigationBar: tabs.length < 2
            ? null
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (i) => context.go(tabs[i].path),
                destinations: [
                  for (final t in tabs)
                    NavigationDestination(icon: Icon(t.icon), label: t.label),
                ],
              ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(tabs[i].path),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.glow(AppTheme.primaryGreen,
                      alpha: .25),
                ),
                child: const Icon(Icons.monitor_heart_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user != null)
                        Tooltip(
                          message:
                              '${user.name}\n${user.role.label}${user.hospital != null ? '\n${user.hospital}' : ''}',
                          child:
                              GradientAvatar(name: user.name, radius: 20),
                        ),
                      const SizedBox(height: 12),
                      IconButton(
                        tooltip: 'Logout',
                        icon: const Icon(Icons.logout_rounded,
                            color: AppTheme.inkMuted),
                        onPressed: () => _logout(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(
                  icon: Icon(t.icon),
                  label: Text(t.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
