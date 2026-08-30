import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

/// Patient management: search by ID, name, or phone; open profiles;
/// register new patients.
class SearchPatientScreen extends ConsumerWidget {
  const SearchPatientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).currentUser;
    final isReceptionist = user?.role == StaffRole.receptionist;
    final isDoctor = user?.role == StaffRole.doctor;
    final text = Theme.of(context).textTheme;

    // Reception's own patient list (GET /patients) is scoped to only the
    // patients *they* registered, so a plain client-side filter can never
    // find a returning patient registered by a colleague. Once they type
    // a query, switch to the global search endpoint instead — every other
    // role's list is already either global (Admin/Lab) or intentionally
    // scoped (Doctor: only their own assigned patients), so they keep the
    // simple local filter.
    final query = ref.watch(patientSearchQueryProvider).trim();
    final useGlobalSearch = isReceptionist && query.isNotEmpty;
    final patientsAsync = useGlobalSearch
        ? ref.watch(patientSearchResultsProvider(query))
        : AsyncValue.data(ref.watch(filteredPatientsProvider));

    // Patients with a visit assigned to this doctor that's ready for a lab
    // request (no request sent yet) — powers the per-row "Send to lab"
    // shortcut below, same criterion as the Queue tab's quick action.
    final assignableVisits = isDoctor
        ? ref.watch(
            doctorQueueProvider((doctorId: user!.staffId, status: 'assigned')))
        : null;
    final labShortcutByPatient = <String, String>{
      for (final v in assignableVisits?.value ?? const []) v.patientId: v.visitId,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        bottom: isReceptionist
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    query.isEmpty
                        ? 'Patients you\'ve registered — search by ID, name, '
                            'or phone to find any patient, including ones '
                            'registered by someone else.'
                        : 'Searching every patient in the system.',
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(color: AppTheme.inkMuted),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: isReceptionist
          ? Container(
              decoration: BoxDecoration(
                gradient: AppTheme.buttonGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.glow(AppTheme.primaryGreen),
              ),
              child: FloatingActionButton.extended(
                onPressed: () => context.go('/patients/add'),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add patient'),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.pagePadding),
        children: [
          // Search bar with soft shadow.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusField),
              boxShadow: AppTheme.cardShadow,
            ),
            child: TextField(
              onChanged: (v) =>
                  ref.read(patientSearchQueryProvider.notifier).set(v),
              decoration: const InputDecoration(
                hintText: 'Search by patient ID, name, or phone number…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...patientsAsync.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, st) => const [
              EmptyState(
                icon: Icons.error_outline_rounded,
                message: 'Could not search patients',
                hint: 'Check the backend connection and try again.',
              ),
            ],
            data: (patients) => [
              Text(
                '${patients.length} patient${patients.length == 1 ? '' : 's'}',
                style: text.labelMedium?.copyWith(
                  color: AppTheme.inkMuted,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < patients.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 50 * (i > 8 ? 8 : i)),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () => context.go('/patients/${patients[i].id}'),
                      child: Row(
                        children: [
                          GradientAvatar(name: patients[i].name, radius: 25),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(patients[i].name,
                                    style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(
                                  '${patients[i].id} · ${patients[i].age} yrs · ${patients[i].gender} · ${patients[i].phone}',
                                  style: text.bodySmall
                                      ?.copyWith(color: AppTheme.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          if (isDoctor)
                            _LatestRisk(patientId: patients[i].id),
                          if (labShortcutByPatient.containsKey(patients[i].id))
                            IconButton(
                              tooltip: 'Send to lab',
                              icon: const Icon(Icons.biotech_rounded,
                                  color: AppTheme.primaryGreen),
                              onPressed: () => context.go(
                                  '/visits/${labShortcutByPatient[patients[i].id]}/lab-request'),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppTheme.inkMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              if (patients.isEmpty)
                EmptyState(
                  icon: Icons.person_search_rounded,
                  message: query.isEmpty
                      ? (isDoctor
                          ? 'No patients assigned to you yet'
                          : 'No patients yet')
                      : 'No patients match your search',
                  hint: query.isEmpty
                      ? (isDoctor
                          ? 'Patients appear here once Reception assigns you a visit.'
                          : null)
                      : 'Try a different name, ID, or phone number.',
                ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _LatestRisk extends ConsumerWidget {
  final String patientId;

  const _LatestRisk({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(predictionHistoryProvider(patientId)).value ?? const [];
    if (history.isEmpty) return const SizedBox.shrink();
    return RiskChip(level: history.last.riskLevel, compact: true);
  }
}
