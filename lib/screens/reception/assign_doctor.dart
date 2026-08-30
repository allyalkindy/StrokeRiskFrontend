import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/visit.dart';
import '../../providers/patient_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

/// Two modes in one screen:
///  * No [visitId] — the "Assign" tab: a picker list of visits still
///    waiting for a doctor.
///  * A [visitId] — the doctor picker for that specific visit.
class AssignDoctorScreen extends ConsumerWidget {
  final String? visitId;

  const AssignDoctorScreen({super.key, this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (visitId == null) {
      return _WaitingVisitsList(
        onPick: (id) => context.go('/reception/assign/$id'),
      );
    }
    return _AssignDoctorForm(visitId: visitId!);
  }
}

class _WaitingVisitsList extends ConsumerWidget {
  final void Function(String visitId) onPick;

  const _WaitingVisitsList({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(visitQueueProvider(null));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Doctor')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(visitQueueProvider(null)),
        child: queueAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.error_outline_rounded,
                message: 'Could not load visits',
                hint: 'Pull down to try again.',
              ),
            ],
          ),
          data: (visits) {
            final waiting = visits
                .where((v) => v.status == VisitStatus.waitingAssignment)
                .toList()
              ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
            return ListView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: [
                Text(
                  '${waiting.length} awaiting assignment',
                  style: text.labelMedium
                      ?.copyWith(color: AppTheme.inkMuted, letterSpacing: .3),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < waiting.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeSlideIn(
                      delay: Duration(milliseconds: 40 * (i > 8 ? 8 : i)),
                      child: _WaitingRow(
                        visit: waiting[i],
                        onTap: () => onPick(waiting[i].visitId),
                      ),
                    ),
                  ),
                if (waiting.isEmpty)
                  const EmptyState(
                    icon: Icons.task_alt_rounded,
                    message: 'Nothing waiting on assignment',
                    hint: 'Every visit today already has a doctor.',
                  ),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WaitingRow extends ConsumerWidget {
  final Visit visit;
  final VoidCallback onTap;

  const _WaitingRow({required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientByIdProvider(visit.patientId));
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          GradientAvatar(name: patient?.name ?? visit.patientId, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient?.name ?? visit.patientId,
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(visit.patientId,
                    style:
                        text.bodySmall?.copyWith(color: AppTheme.inkMuted)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppTheme.inkMuted),
        ],
      ),
    );
  }
}

class _AssignDoctorForm extends ConsumerStatefulWidget {
  final String visitId;

  const _AssignDoctorForm({required this.visitId});

  @override
  ConsumerState<_AssignDoctorForm> createState() => _AssignDoctorFormState();
}

class _AssignDoctorFormState extends ConsumerState<_AssignDoctorForm> {
  String? _selectedDoctorId;
  bool _assigning = false;

  Future<void> _assign() async {
    if (_selectedDoctorId == null) return;
    setState(() => _assigning = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(visitActionsProvider).assignDoctor(
            visitId: widget.visitId,
            doctorId: _selectedDoctorId!,
          );
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Doctor assigned.')));
      final patientId =
          ref.read(visitDetailProvider(widget.visitId)).value?.patient.id;
      context.go(patientId == null ? '/patients' : '/patients/$patientId');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Could not assign a doctor — check the backend connection.')));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitAsync = ref.watch(visitDetailProvider(widget.visitId));
    final doctorsAsync = ref.watch(activeDoctorsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/reception/assign')),
        title: const Text('Assign Doctor'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                visitAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => Text('Could not load this visit.',
                      style:
                          text.bodySmall?.copyWith(color: AppTheme.inkMuted)),
                  data: (detail) => FadeSlideIn(
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GradientAvatar(name: detail.patient.name, radius: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(detail.patient.name,
                                    style: text.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${detail.patient.id} · ${detail.patient.age} yrs · ${detail.patient.gender}',
                                  style: text.bodySmall
                                      ?.copyWith(color: AppTheme.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          if (detail.assignedDoctor != null)
                            PillTag(
                              label: 'Was: ${detail.assignedDoctor!.name}',
                              icon: Icons.medical_services_rounded,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.cardGap),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: 'Available doctors',
                            icon: Icons.medical_services_outlined),
                        doctorsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, st) => Text(
                              'Could not load the doctor list.',
                              style: text.bodySmall
                                  ?.copyWith(color: AppTheme.inkMuted)),
                          data: (doctors) {
                            if (doctors.isEmpty) {
                              return const EmptyState(
                                icon: Icons.person_off_rounded,
                                message: 'No active doctors available',
                              );
                            }
                            return RadioGroup<String>(
                              groupValue: _selectedDoctorId,
                              onChanged: (v) =>
                                  setState(() => _selectedDoctorId = v),
                              child: Column(
                                children: [
                                  for (final d in doctors)
                                    RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      activeColor: AppTheme.primaryGreen,
                                      value: d.staffId,
                                      title: Text(d.name),
                                      subtitle: Text(
                                          d.hospital ?? d.staffId),
                                      secondary: GradientAvatar(
                                          name: d.name, radius: 18),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Assign doctor',
                  icon: Icons.check_rounded,
                  loading: _assigning,
                  onPressed: _selectedDoctorId == null ? null : _assign,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
