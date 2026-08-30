import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/prediction.dart';
import '../../models/visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/visit_queue_row.dart';

class DoctorDashboard extends ConsumerWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(authProvider).currentUser;
    final patients = ref.watch(patientListProvider);
    final text = Theme.of(context).textTheme;
    final myQueue = doctor == null
        ? const AsyncValue<List<Visit>>.data([])
        : ref.watch(
            doctorQueueProvider((doctorId: doctor.staffId, status: null)));

    // Latest risk level per patient, for the stat cards and distribution.
    final latest = <String, Prediction>{};
    for (final p in patients) {
      final history =
          ref.watch(predictionHistoryProvider(p.id)).value ?? const [];
      if (history.isNotEmpty) latest[p.id] = history.last;
    }
    final counts = {
      RiskLevel.low: 0,
      RiskLevel.medium: 0,
      RiskLevel.high: 0,
    };
    for (final pr in latest.values) {
      counts[pr.riskLevel] = counts[pr.riskLevel]! + 1;
    }
    final recent = latest.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Assessments per month over the last 6 months (patient trends).
    final now = DateTime.now();
    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - 5 + i));
    final all = latest.keys
        .expand((id) =>
            ref.watch(predictionHistoryProvider(id)).value ??
            const <Prediction>[])
        .toList();
    final trend = [
      for (final m in months)
        all
            .where((p) => p.date.year == m.year && p.date.month == m.month)
            .length
            .toDouble(),
    ];

    final firstName =
        (doctor?.name ?? 'Doctor').replaceAll('Dr. ', '').split(' ').first;
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // Today's active (non-completed) queue, soonest arrival first — powers
    // the hero glance strip, the "Up next" spotlight, and the 4th stat
    // tile, so it's computed once and shared instead of re-filtered.
    final activeQueue = (myQueue.value ?? const <Visit>[])
        .where((v) => v.status != VisitStatus.completed)
        .toList()
      ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
    final nextUp = activeQueue.isEmpty ? null : activeQueue.first;

    return Scaffold(
      body: Column(
        children: [
          // Gradient greeting header.
          HeroHeader(
            child: Column(
              children: [
                Row(
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
                            '$greeting, Dr. $firstName 👋',
                            style: text.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (doctor?.hospital != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              doctor!.hospital!,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: .7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    GradientAvatar(name: doctor?.name ?? 'Doctor', radius: 22),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _GlassStat(
                        icon: Icons.groups_rounded,
                        value: '${activeQueue.length}',
                        label: 'In queue today',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _GlassStat(
                        icon: Icons.warning_rounded,
                        value: '${counts[RiskLevel.high]}',
                        label: 'High-risk patients',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: [
                // Stat tiles
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 1100
                      ? 4
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
                      title: 'High-risk patients',
                      value: '${counts[RiskLevel.high]}',
                      icon: Icons.warning_rounded,
                      color: AppTheme.riskHigh,
                    ),
                    HealthCard(
                      title: 'Recent assessments',
                      value: '${recent.length}',
                      icon: Icons.monitor_heart_rounded,
                      color: AppTheme.midGreen,
                      subtitle: 'latest per patient',
                    ),
                    HealthCard(
                      title: 'In queue today',
                      value: '${activeQueue.length}',
                      icon: Icons.groups_rounded,
                      color: AppTheme.deepGreen,
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

                // Up next — the soonest-arrived patient still waiting on
                // this doctor, surfaced as a one-tap spotlight instead of
                // making them scan the full queue list below for it.
                if (nextUp != null) ...[
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    child: _UpNextCard(visit: nextUp),
                  ),
                  const SizedBox(height: AppConstants.cardGap),
                ],

                // My patient queue — today's visits assigned to this doctor.
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SectionHeader(
                              title: 'My patient queue',
                              icon: Icons.assignment_ind_outlined,
                            ),
                            const SizedBox(width: 8),
                            const LiveDot(),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Refresh',
                              icon: const Icon(Icons.refresh_rounded,
                                  color: AppTheme.inkMuted),
                              onPressed: doctor == null
                                  ? null
                                  : () => ref.invalidate(doctorQueueProvider((
                                      doctorId: doctor.staffId,
                                      status: null))),
                            ),
                          ],
                        ),
                        myQueue.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: CircularProgressIndicator()),
                          ),
                          error: (e, st) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Could not load your queue.',
                              style: text.bodySmall
                                  ?.copyWith(color: AppTheme.inkMuted),
                            ),
                          ),
                          data: (visits) {
                            // Assessed patients drop off the queue — still
                            // reachable via the Patients tab.
                            final active = visits
                                .where((v) =>
                                    v.status != VisitStatus.completed)
                                .toList();
                            if (active.isEmpty) {
                              return const EmptyState(
                                icon: Icons.event_available_outlined,
                                message: 'No patients queued for you today',
                                hint:
                                    'Visits the front desk assigns to you show up here.',
                              );
                            }
                            return Column(
                              children: [
                                for (final v in active) ...[
                                  VisitQueueRow(visit: v),
                                  if (v != active.last)
                                    const Divider(height: 1),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.cardGap),

                // Charts row
                LayoutBuilder(builder: (context, c) {
                  final side = c.maxWidth >= 860;
                  final charts = [
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: ChartCard(
                        title: 'Risk distribution',
                        subtitle: 'Latest assessment per patient',
                        child: RiskDistributionChart(
                          low: counts[RiskLevel.low]!,
                          medium: counts[RiskLevel.medium]!,
                          high: counts[RiskLevel.high]!,
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 320),
                      child: ChartCard(
                        title: 'Assessments per month',
                        subtitle: 'Last 6 months',
                        child: AppLineChart(
                          values: trend,
                          xLabels: [
                            for (final m in months)
                              DateFormat('MMM').format(m)
                          ],
                          minY: 0,
                        ),
                      ),
                    ),
                  ];
                  if (!side) {
                    return Column(
                      children: [
                        charts[0],
                        const SizedBox(height: AppConstants.cardGap),
                        charts[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: AppConstants.cardGap),
                      Expanded(child: charts[1]),
                    ],
                  );
                }),
                const SizedBox(height: AppConstants.cardGap),

                // Recent assessments list
                FadeSlideIn(
                  delay: const Duration(milliseconds: 400),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Recent assessments',
                                style: text.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.go('/patients'),
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final pr in recent.take(5)) ...[
                          _RecentRow(prediction: pr),
                          if (pr != recent.take(5).last)
                            const Divider(height: 1),
                        ],
                        if (recent.isEmpty)
                          const EmptyState(
                            icon: Icons.monitor_heart_outlined,
                            message: 'No assessments yet',
                            hint:
                                'Run your first assessment from the Assess tab.',
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

class _RecentRow extends ConsumerWidget {
  final Prediction prediction;

  const _RecentRow({required this.prediction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientByIdProvider(prediction.patientId));
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/patients/${prediction.patientId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            GradientAvatar(
                name: patient?.name ?? prediction.patientId, radius: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient?.name ?? prediction.patientId,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${prediction.patientId} · ${DateFormat('d MMM yyyy').format(prediction.date)}',
                    style:
                        text.bodySmall?.copyWith(color: AppTheme.inkMuted),
                  ),
                ],
              ),
            ),
            Text(
              '${(prediction.probability * 100).round()}%',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            RiskChip(level: prediction.riskLevel, compact: true),
          ],
        ),
      ),
    );
  }
}

/// Frosted stat chip for the hero header — a plain [HealthCard] would
/// fight the dark gradient background, so this uses a translucent white
/// tint instead of a solid card surface.
class _GlassStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _GlassStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: text.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spotlight card for the soonest-arrived patient still waiting in the
/// queue — a one-tap shortcut instead of making the doctor scan the full
/// list below for who's next.
class _UpNextCard extends ConsumerWidget {
  final Visit visit;

  const _UpNextCard({required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientByIdProvider(visit.patientId));
    final text = Theme.of(context).textTheme;
    final needsLab = visit.status == VisitStatus.assigned;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.buttonGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.glow(AppTheme.primaryGreen),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          onTap: () => context.go(needsLab
              ? '/visits/${visit.visitId}/lab-request'
              : '/visits/${visit.visitId}'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'UP NEXT',
                    style: text.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                GradientAvatar(
                    name: patient?.name ?? visit.patientId, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient?.name ?? visit.patientId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Arrived ${DateFormat('HH:mm').format(visit.arrivalTime)} · ${visit.status.label}',
                        style: text.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: .8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        needsLab ? 'Send to lab' : 'Continue',
                        style: text.labelMedium?.copyWith(
                          color: AppTheme.deepGreen,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppTheme.deepGreen),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
