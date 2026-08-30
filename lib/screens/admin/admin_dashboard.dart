import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authProvider).currentUser;
    final staffAsync = ref.watch(staffListProvider);
    final patients = ref.watch(patientListProvider);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    final staff = staffAsync.value ?? const <Staff>[];
    final counts = {
      for (final r in StaffRole.values)
        r: staff.where((s) => s.role == r).length,
    };
    final activeCount = staff.where((s) => s.active).length;

    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(now),
                        style: text.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .7),
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Karibu, ${admin?.name ?? 'Admin'}',
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'System overview',
                        style: text.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
                GradientAvatar(name: admin?.name ?? 'Admin', radius: 22),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: [
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 1100
                      ? 3
                      : c.maxWidth >= 640
                          ? 2
                          : 1;
                  final w =
                      (c.maxWidth - (cols - 1) * AppConstants.cardGap) / cols;
                  final tiles = [
                    HealthCard(
                      title: 'Total patients',
                      value: '${patients.length}',
                      icon: Icons.people_alt_rounded,
                    ),
                    HealthCard(
                      title: 'Active staff',
                      value: '$activeCount',
                      icon: Icons.verified_user_rounded,
                      color: AppTheme.riskLow,
                      subtitle: 'of ${staff.length} total',
                    ),
                    HealthCard(
                      title: StaffRole.doctor.label,
                      value: '${counts[StaffRole.doctor] ?? 0}',
                      icon: StaffRole.doctor.icon,
                      color: StaffRole.doctor.color,
                    ),
                    HealthCard(
                      title: StaffRole.receptionist.label,
                      value: '${counts[StaffRole.receptionist] ?? 0}',
                      icon: StaffRole.receptionist.icon,
                      color: StaffRole.receptionist.color,
                    ),
                    HealthCard(
                      title: StaffRole.labScientist.label,
                      value: '${counts[StaffRole.labScientist] ?? 0}',
                      icon: StaffRole.labScientist.icon,
                      color: StaffRole.labScientist.color,
                    ),
                    HealthCard(
                      title: StaffRole.admin.label,
                      value: '${counts[StaffRole.admin] ?? 0}',
                      icon: StaffRole.admin.icon,
                      color: StaffRole.admin.color,
                    ),
                  ];
                  return Wrap(
                    spacing: AppConstants.cardGap,
                    runSpacing: AppConstants.cardGap,
                    children: [
                      for (var i = 0; i < tiles.length; i++)
                        SizedBox(
                          width: w,
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 80 * i),
                            child: tiles[i],
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: AppConstants.cardGap),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: 'Staff management',
                            icon: Icons.badge_outlined),
                        Text(
                          'Create and manage staff accounts — only Admins '
                          'can add new Receptionists, Lab Scientists, '
                          'Doctors, or fellow Admins.',
                          style: text.bodyMedium
                              ?.copyWith(color: AppTheme.inkSecondary),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Manage staff',
                          icon: Icons.arrow_forward_rounded,
                          outlined: true,
                          onPressed: () => context.go('/admin/staff'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
