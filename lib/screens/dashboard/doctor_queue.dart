import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/visit_queue_row.dart';

/// Every visit currently assigned to this doctor, any status — the full
/// worklist behind the Home dashboard's "My patient queue" card.
class DoctorQueueScreen extends ConsumerWidget {
  const DoctorQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(authProvider).currentUser;
    final text = Theme.of(context).textTheme;
    final args = doctor == null ? null : (doctorId: doctor.staffId, status: null);
    final queueAsync = args == null
        ? const AsyncValue<List<Visit>>.data([])
        : ref.watch(doctorQueueProvider(args));

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
                        DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                        style: text.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .7),
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'My patient queue',
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                GradientAvatar(name: doctor?.name ?? 'Doctor', radius: 22),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (args != null) ref.invalidate(doctorQueueProvider(args));
              },
              child: queueAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.error_outline_rounded,
                      message: 'Could not load your queue',
                      hint: 'Pull down to try again.',
                    ),
                  ],
                ),
                data: (visits) {
                  // Assessed patients drop off the worklist — they're
                  // still reachable via the Patients tab.
                  final sorted = visits
                      .where((v) => v.status != VisitStatus.completed)
                      .toList()
                    ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
                  return ListView(
                    padding: const EdgeInsets.all(AppConstants.pagePadding),
                    children: [
                      Text(
                        '${sorted.length} patient${sorted.length == 1 ? '' : 's'} assigned to you',
                        style: text.labelMedium?.copyWith(
                            color: AppTheme.inkMuted, letterSpacing: .3),
                      ),
                      const SizedBox(height: 10),
                      AppCard(
                        child: Column(
                          children: [
                            for (final v in sorted) ...[
                              VisitQueueRow(visit: v),
                              if (v != sorted.last) const Divider(height: 1),
                            ],
                            if (sorted.isEmpty)
                              const EmptyState(
                                icon: Icons.event_available_outlined,
                                message: 'No patients queued for you',
                                hint:
                                    'Visits the front desk assigns to you show up here.',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
