import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lab_request.dart';
import '../../models/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/visit_queue_row.dart';

/// The stroke risk assessment form. The clinical numbers (BP, glucose,
/// cholesterol, BMI, heart rate) are no longer typed by hand — they are
/// all resolved server-side from the visit's synced lab result and shown
/// here read-only for context. Only the doctor's interview-based history
/// flags are collected.
class AssessmentFormScreen extends ConsumerStatefulWidget {
  /// The visit this assessment belongs to. Required by the backend
  /// contract — reached via the "Continue to assessment" button on a
  /// visit's detail page once lab results are in.
  final String? visitId;

  const AssessmentFormScreen({super.key, this.visitId});

  @override
  ConsumerState<AssessmentFormScreen> createState() =>
      _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends ConsumerState<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _heartDisease = false;
  bool _smoking = false;
  bool _alcohol = false;
  String _activity = 'Moderate';
  String _diet = 'Average';
  bool _familyHistory = false;

  Future<void> _predict(String visitId) async {
    if (!_formKey.currentState!.validate()) return;
    final input = AssessmentInput(
      visitId: visitId,
      heartDisease: _heartDisease,
      smoking: _smoking,
      alcohol: _alcohol,
      physicalActivity: _activity,
      diet: _diet,
      familyHistory: _familyHistory,
    );
    try {
      await ref.read(predictionProvider.notifier).analyze(input);
      if (mounted) context.go('/assessment/result');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(friendlyError(e, 'Prediction failed.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitId = widget.visitId;

    if (visitId == null) {
      return const _ReadyToAssessList();
    }

    final visitAsync = ref.watch(visitDetailProvider(visitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Stroke Assessment')),
      body: visitAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            message: 'Could not load this visit',
            hint: 'Check the backend connection and try again.',
          ),
        ),
        data: (detail) {
          final loading = ref.watch(predictionProvider).loading;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Patient context.
                      FadeSlideIn(
                        child: AppCard(
                          child: Row(
                            children: [
                              GradientAvatar(
                                  name: detail.patient.name, radius: 24),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(detail.patient.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    Text(
                                      '${detail.patient.id} · ${detail.patient.age} yrs · ${detail.patient.gender}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: AppTheme.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.cardGap),

                      // Read-only synced clinical data.
                      _SyncedDataCard(visitId: visitId),
                      const SizedBox(height: AppConstants.cardGap),

                      // Known history (interview-based).
                      _FormCard(
                        title: 'Known conditions',
                        icon: Icons.medical_information_outlined,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Heart disease history'),
                            value: _heartDisease,
                            onChanged: (v) =>
                                setState(() => _heartDisease = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Family history of stroke'),
                            value: _familyHistory,
                            onChanged: (v) =>
                                setState(() => _familyHistory = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.cardGap),

                      // Lifestyle
                      _FormCard(
                        title: 'Lifestyle',
                        icon: Icons.self_improvement_rounded,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Smoking'),
                            value: _smoking,
                            onChanged: (v) => setState(() => _smoking = v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Alcohol consumption'),
                            value: _alcohol,
                            onChanged: (v) => setState(() => _alcohol = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _activity,
                                  decoration: const InputDecoration(
                                      labelText: 'Physical activity'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Low', child: Text('Low')),
                                    DropdownMenuItem(
                                        value: 'Moderate',
                                        child: Text('Moderate')),
                                    DropdownMenuItem(
                                        value: 'High', child: Text('High')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _activity = v ?? 'Moderate'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _diet,
                                  decoration: const InputDecoration(
                                      labelText: 'Diet'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Poor', child: Text('Poor')),
                                    DropdownMenuItem(
                                        value: 'Average',
                                        child: Text('Average')),
                                    DropdownMenuItem(
                                        value: 'Healthy',
                                        child: Text('Healthy')),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _diet = v ?? 'Average'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      AppButton(
                        label: 'Predict Stroke Risk',
                        icon: Icons.online_prediction_rounded,
                        loading: loading,
                        onPressed: () => _predict(visitId),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Read-only card showing the clinical data this assessment will
/// actually be computed from: BP/heart rate are the doctor's own
/// recorded vitals for the visit, BMI comes from the patient's
/// registration record, and glucose/cholesterol are the synced lab
/// result.
class _SyncedDataCard extends ConsumerWidget {
  final String visitId;

  const _SyncedDataCard({required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final visitAsync = ref.watch(visitDetailProvider(visitId));
    final visit = visitAsync.value?.visit;
    final patient = visitAsync.value?.patient;
    final labRequestId = visitAsync.value?.labRequest?.labRequestId;
    final labAsync = labRequestId == null
        ? null
        : ref.watch(labRequestPollingProvider(labRequestId));
    final result = labAsync?.value?.result;

    // Bool flags whether the value is outside the normal reference range.
    final bpAbnormal = visit?.systolicBp != null &&
            LabTestCatalog.isAbnormal('systolic_bp', visit!.systolicBp!.toDouble()) ||
        visit?.diastolicBp != null &&
            LabTestCatalog.isAbnormal('diastolic_bp', visit!.diastolicBp!.toDouble());
    final rows = <String, ({String value, bool abnormal})>{
      'Blood pressure': (
        value: visit?.systolicBp != null && visit?.diastolicBp != null
            ? '${visit!.systolicBp}/${visit.diastolicBp} mmHg'
            : 'Not available',
        abnormal: bpAbnormal,
      ),
      'Blood glucose': (
        value: result?.bloodGlucose != null
            ? '${LabTestCatalog.format('blood_glucose', result!.bloodGlucose!)} mmol/L'
            : 'Not available',
        abnormal: result?.bloodGlucose != null &&
            LabTestCatalog.isAbnormal('blood_glucose', result!.bloodGlucose!),
      ),
      'Cholesterol': (
        value: result?.cholesterol != null
            ? '${LabTestCatalog.format('cholesterol', result!.cholesterol!)} mmol/L'
            : 'Not available',
        abnormal: result?.cholesterol != null &&
            LabTestCatalog.isAbnormal('cholesterol', result!.cholesterol!),
      ),
      'BMI': (
        value: patient?.bmi != null ? patient!.bmi!.toStringAsFixed(1) : 'Not available',
        abnormal: (patient?.bmi ?? 0) >= 30,
      ),
      'Heart rate': (
        value: visit?.heartRate != null ? '${visit!.heartRate} bpm' : 'Not available',
        abnormal: visit?.heartRate != null &&
            LabTestCatalog.isAbnormal('heart_rate', visit!.heartRate!.toDouble()),
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: 'Synced clinical data',
              icon: Icons.sync_alt_rounded),
          Text(
            'BP/heart rate from your recorded vitals; BMI from the '
            'patient\'s registration record; glucose and cholesterol '
            'from the lab result.',
            style: text.bodySmall?.copyWith(color: AppTheme.inkMuted),
          ),
          const SizedBox(height: 8),
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.key,
                        style:
                            text.bodySmall?.copyWith(color: AppTheme.inkMuted)),
                  ),
                  Text(e.value.value,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (e.value.abnormal) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.warning_rounded,
                        size: 15, color: AppTheme.riskHigh),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, icon: icon),
          ...children,
        ],
      ),
    );
  }
}

/// Landing state for the Assess tab reached with no `?visit=` param: the
/// doctor's own visits whose lab work is done and are next up for a
/// prediction, so this tab is a real worklist rather than a dead end.
class _ReadyToAssessList extends ConsumerWidget {
  const _ReadyToAssessList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(authProvider).currentUser;
    final text = Theme.of(context).textTheme;
    final queueAsync = doctor == null
        ? null
        : ref.watch(doctorQueueProvider(
            (doctorId: doctor.staffId, status: 'lab_completed')));

    return Scaffold(
      appBar: AppBar(title: const Text('Stroke Assessment')),
      body: queueAsync == null
          ? const Center(child: CircularProgressIndicator())
          : queueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => const Center(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  message: 'Could not load your worklist',
                  hint: 'Check the backend connection and try again.',
                ),
              ),
              data: (visits) {
                if (visits.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      icon: Icons.assignment_turned_in_outlined,
                      message: 'Nothing ready to assess right now',
                      hint:
                          'Patients appear here once their lab results are in.',
                    ),
                  );
                }
                final sorted = [...visits]
                  ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));
                return ListView(
                  padding: const EdgeInsets.all(AppConstants.pagePadding),
                  children: [
                    Text(
                      'Ready for assessment',
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
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
