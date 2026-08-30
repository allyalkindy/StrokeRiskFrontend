import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../models/patient.dart';
import '../../models/prediction.dart';
import '../../models/staff.dart';
import '../../models/visit.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

Future<void> _startVisitAndAssign(
  BuildContext context,
  WidgetRef ref,
  Patient patient,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final visit = await ref
        .read(visitActionsProvider)
        .createVisit(patientId: patient.id);
    if (context.mounted) context.go('/reception/assign/${visit.visitId}');
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not start the visit — check the backend connection.',
        ),
      ),
    );
  }
}

Future<void> _reassessPatient(
  BuildContext context,
  WidgetRef ref,
  Patient patient,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final visit =
        await ref.read(visitActionsProvider).reassessPatient(patient.id);
    // A fresh reassessment always starts at "assigned" with no lab
    // request yet — skip straight to picking lab tests instead of
    // landing on the visit workspace first.
    if (context.mounted) context.go('/visits/${visit.visitId}/lab-request');
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text(friendlyError(
            e, 'Could not start a new assessment — check the backend connection.'))));
  }
}

Future<void> _confirmDeletePatient(
  BuildContext context,
  WidgetRef ref,
  Patient patient,
) async {
  final confirmed = await confirmDestructiveAction(
    context,
    title: 'Delete patient?',
    message:
        'This permanently removes ${patient.name} and all of their '
        'assessments, recommendations, and readings. This cannot be undone.',
  );
  if (!confirmed) return;

  try {
    await ref.read(patientListProvider.notifier).deletePatient(patient.id);
    if (context.mounted) {
      context.go('/patients');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${patient.name} deleted')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete patient')));
    }
  }
}

Future<void> _confirmDeleteAssessment(
  BuildContext context,
  WidgetRef ref,
  String patientId,
  Prediction prediction,
) async {
  final confirmed = await confirmDestructiveAction(
    context,
    title: 'Delete assessment?',
    message:
        'This permanently removes this assessment from the patient\'s '
        'history. This cannot be undone.',
  );
  if (!confirmed) return;

  try {
    await apiService.deletePrediction(patientId, prediction.id);
    ref.invalidate(predictionHistoryProvider(patientId));
    // Deleting a prediction cascades to its Recommendation row on the
    // backend — drop the cached list too, or the review screen keeps
    // pointing at a recommendation_id that no longer exists.
    ref.invalidate(recommendationsProvider(patientId));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Assessment deleted')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete assessment')),
      );
    }
  }
}

class PatientProfileScreen extends ConsumerWidget {
  final String patientId;

  const PatientProfileScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientByIdProvider(patientId));
    final history =
        ref.watch(predictionHistoryProvider(patientId)).value ?? const [];
    final visits =
        ref.watch(patientVisitsProvider(patientId)).value ?? const [];
    final currentUser = ref.watch(authProvider).currentUser;
    final canDelete = currentUser?.role == StaffRole.admin;
    final isAdmin = currentUser?.role == StaffRole.admin;
    final isDoctor = currentUser?.role == StaffRole.doctor;
    final isReceptionist = currentUser?.role == StaffRole.receptionist;
    // Newest open visit assigned to this doctor for this patient, if any
    // — powers the "New assessment" button below (visits is already
    // newest-first, per visits_for_patient's ordering).
    Visit? openVisit;
    for (final v in visits) {
      if (v.assignedDoctorId == currentUser?.staffId &&
          v.status != VisitStatus.completed &&
          v.status != VisitStatus.cancelled) {
        openVisit = v;
        break;
      }
    }
    // Lets the doctor self-start a fresh follow-up visit (skipping
    // Reception) once they've completed at least one prior assessment
    // for this patient — any time, not just today — see visits/reassess
    // on the backend.
    final hasCompletedAssessment = visits.any((v) =>
        v.assignedDoctorId == currentUser?.staffId &&
        v.status == VisitStatus.completed);
    final text = Theme.of(context).textTheme;

    if (patient == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/patients')),
        ),
        body: const Center(
          child: EmptyState(
            icon: Icons.person_off_rounded,
            message: 'Patient not found',
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Gradient identity header.
          HeroHeader(
            padding: const EdgeInsets.fromLTRB(8, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BackButton(
                      color: Colors.white,
                      onPressed: () => context.go('/patients'),
                    ),
                    const Spacer(),
                    if (canDelete)
                      IconButton(
                        tooltip: 'Delete patient',
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            _confirmDeletePatient(context, ref, patient),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: [
                      GradientAvatar(name: patient.name, radius: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              style: text.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                PillTag(
                                  label: patient.id,
                                  icon: Icons.tag_rounded,
                                  color: Colors.white,
                                  background: Colors.white.withValues(
                                    alpha: .16,
                                  ),
                                ),
                                PillTag(
                                  label: '${patient.age} yrs',
                                  icon: Icons.cake_outlined,
                                  color: Colors.white,
                                  background: Colors.white.withValues(
                                    alpha: .16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 860;
                    final left = Column(
                      children: [
                        if (isReceptionist) ...[
                          FadeSlideIn(
                            child: AppButton(
                              label: 'Start visit & assign doctor',
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: () =>
                                  _startVisitAndAssign(context, ref, patient),
                            ),
                          ),
                          const SizedBox(height: AppConstants.cardGap),
                        ],
                        FadeSlideIn(
                          child: _InfoCard(
                            title: 'Personal information',
                            icon: Icons.person_outline_rounded,
                            rows: {
                              'Patient ID': patient.id,
                              'Age': '${patient.age} years',
                              'Gender': patient.gender,
                              'Phone': patient.phone,
                            },
                          ),
                        ),
                        if (!isAdmin) ...[
                          // Height/weight/BMI (recorded once by Reception
                          // at registration) and the registration date —
                          // not shown to Admin, whose patient view is
                          // intentionally limited to identity fields only.
                          const SizedBox(height: AppConstants.cardGap),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 80),
                            child: _InfoCard(
                              title: 'Registration details',
                              icon: Icons.monitor_weight_outlined,
                              rows: {
                                'Height': patient.height != null
                                    ? '${patient.height!.toStringAsFixed(0)} cm'
                                    : 'Not recorded',
                                'Weight': patient.weight != null
                                    ? '${patient.weight!.toStringAsFixed(0)} kg'
                                    : 'Not recorded',
                                'BMI': patient.bmi != null
                                    ? patient.bmi!.toStringAsFixed(1)
                                    : 'Not available',
                                'Registered': patient.registeredAt != null
                                    ? DateFormat('d MMM yyyy')
                                        .format(patient.registeredAt!)
                                    : 'Not recorded',
                              },
                            ),
                          ),
                          const SizedBox(height: AppConstants.cardGap),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 100),
                            child: _InfoCard(
                              title: 'Medical history',
                              icon: Icons.medical_information_outlined,
                              body: patient.medicalHistory.isEmpty
                                  ? 'None recorded'
                                  : patient.medicalHistory,
                            ),
                          ),
                        ],
                        if (isDoctor) ...[
                          const SizedBox(height: AppConstants.cardGap),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 180),
                            child: _InfoCard(
                              title: 'Lifestyle',
                              icon: Icons.self_improvement_rounded,
                              body: patient.lifestyle.isEmpty
                                  ? 'Not recorded'
                                  : patient.lifestyle,
                            ),
                          ),
                        ],
                      ],
                    );
                    final right = Column(
                      children: [
                        // Previous visits — what Receptionist (who
                        // created these check-ins) reviews. Not shown to
                        // Doctor (redundant with the "Previous
                        // assessments" card below) or Admin, whose
                        // patient view is intentionally limited to
                        // identity fields only.
                        if (!isAdmin && !isDoctor)
                        FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Previous visits',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (visits.isEmpty)
                                    const EmptyState(
                                      icon: Icons.event_note_outlined,
                                      message: 'No visits yet',
                                      hint:
                                          'Visits are created by Reception when the patient checks in.',
                                    ),
                                  for (final v in visits) ...[
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () =>
                                          context.go('/visits/${v.visitId}'),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              v.status.icon,
                                              size: 18,
                                              color: v.status.color,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              DateFormat(
                                                'd MMM yyyy',
                                              ).format(v.arrivalTime),
                                              style: text.bodyMedium?.copyWith(
                                                color: AppTheme.inkSecondary,
                                              ),
                                            ),
                                            const Spacer(),
                                            PillTag(
                                              label: v.status.label,
                                              color: v.status.color,
                                              background: v.status.color
                                                  .withValues(alpha: .12),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: AppTheme.inkMuted,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (v != visits.last)
                                      const Divider(height: 1),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if (isDoctor) ...[
                          const SizedBox(height: AppConstants.cardGap),
                          // Previous results
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 160),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Previous assessments',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (history.isEmpty)
                                    const EmptyState(
                                      icon: Icons.monitor_heart_outlined,
                                      message: 'No assessments yet',
                                      hint:
                                          'Run the first assessment for this patient.',
                                    ),
                                  for (final pr in history.reversed) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: AppTheme.softMint,
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                            child: const Icon(
                                              Icons.event_note_rounded,
                                              size: 18,
                                              color: AppTheme.deepGreen,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            DateFormat(
                                              'MMM yyyy',
                                            ).format(pr.date),
                                            style: text.bodyMedium?.copyWith(
                                              color: AppTheme.inkSecondary,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${(pr.probability * 100).round()}%',
                                            style: text.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          RiskChip(
                                            level: pr.riskLevel,
                                            compact: true,
                                          ),
                                          IconButton(
                                            tooltip: 'Delete assessment',
                                            visualDensity:
                                                VisualDensity.compact,
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AppTheme.inkMuted,
                                            ),
                                            onPressed: () =>
                                                _confirmDeleteAssessment(
                                                  context,
                                                  ref,
                                                  patientId,
                                                  pr,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (pr != history.first)
                                      const Divider(height: 1),
                                  ],
                                  const SizedBox(height: 12),
                                  if (isDoctor) ...[
                                    AppButton(
                                      label: 'New assessment',
                                      icon: Icons.add_circle_outline_rounded,
                                      onPressed: openVisit != null
                                          ? () => context.go(
                                              '/visits/${openVisit!.visitId}/lab-request')
                                          : hasCompletedAssessment
                                              ? () => _reassessPatient(
                                                  context, ref, patient)
                                              : null,
                                    ),
                                    if (openVisit == null &&
                                        !hasCompletedAssessment)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'No open visit for this patient yet — '
                                          'ask Reception to create a follow-up visit.',
                                          style: text.labelSmall?.copyWith(
                                            color: AppTheme.inkMuted,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                  ],
                                  AppButton(
                                    label: 'View analytics & reports',
                                    icon: Icons.insights_rounded,
                                    outlined: true,
                                    onPressed: () => context.go(
                                      '/analytics?patient=$patientId',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          left,
                          const SizedBox(height: AppConstants.cardGap),
                          right,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: AppConstants.cardGap),
                        Expanded(flex: 2, child: right),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, String>? rows;
  final String? body;

  const _InfoCard({
    required this.title,
    required this.icon,
    this.rows,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, icon: icon),
          if (rows != null)
            for (final e in rows!.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: text.bodySmall?.copyWith(
                          color: AppTheme.inkMuted,
                        ),
                      ),
                    ),
                    Text(
                      e.value,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          if (body != null)
            Text(
              body!,
              style: text.bodyMedium?.copyWith(color: AppTheme.inkSecondary),
            ),
        ],
      ),
    );
  }
}
