import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lab_request.dart';
import '../../models/staff.dart';
import '../../models/visit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

/// A doctor's single-visit workspace: record their own vitals (BP, heart
/// rate), request lab tests (only cholesterol and blood glucose go to
/// the lab), watch the lab results sync in (polled), then continue into
/// the assessment form once both are ready. Receptionist can also open
/// this screen (from a patient's "Previous visits" list) but gets a
/// read-only view — vitals/lab entry and "Continue to assessment" are
/// Doctor-only actions.
class VisitDetailScreen extends ConsumerWidget {
  final String visitId;

  const VisitDetailScreen({super.key, required this.visitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(visitDetailProvider(visitId));
    // Doctors land back on their dashboard; anyone else (Receptionist,
    // viewing read-only from a patient's "Previous visits" list) goes
    // back to their own home tab instead — /dashboard is Doctor-only and
    // would just bounce them straight back out via the router redirect.
    final homePath =
        ref.watch(authProvider).currentUser?.role.homePath ?? '/dashboard';

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(homePath)),
        title: const Text('Visit'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(visitDetailProvider(visitId)),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            message: 'Could not load this visit',
            hint: 'Check the backend connection and try again.',
          ),
        ),
        data: (detail) => _VisitDetailBody(visitId: visitId, detail: detail),
      ),
    );
  }
}

class _VisitDetailBody extends ConsumerWidget {
  final String visitId;
  final VisitDetail detail;

  const _VisitDetailBody({required this.visitId, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final patient = detail.patient;
    final visit = detail.visit;
    final labRequest = detail.labRequest;
    final isDoctor = ref.watch(authProvider).currentUser?.role == StaffRole.doctor;
    final labReady = labRequest != null &&
        ref
                .watch(labRequestPollingProvider(labRequest.labRequestId))
                .value
                ?.request
                .status ==
            LabRequestStatus.completed;
    final readyForAssessment = labReady && visit.hasVitals;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      children: [
        // Patient + visit summary.
        FadeSlideIn(
          child: AppCard(
            child: Row(
              children: [
                GradientAvatar(name: patient.name, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name,
                          style: text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${patient.id} · ${patient.age} yrs · ${patient.gender}',
                        style: text.bodySmall
                            ?.copyWith(color: AppTheme.inkMuted),
                      ),
                    ],
                  ),
                ),
                PillTag(
                  label: visit.status.label,
                  icon: visit.status.icon,
                  color: visit.status.color,
                  background: visit.status.color.withValues(alpha: .12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.cardGap),

        // Vitals — editable by the doctor, read-only for anyone else
        // (e.g. Receptionist reviewing a previous visit).
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: isDoctor
              ? _VitalsCard(visitId: visitId, visit: visit)
              : _VitalsSummaryCard(visit: visit),
        ),
        const SizedBox(height: AppConstants.cardGap),

        // Lab section.
        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: labRequest == null
              ? _NoLabRequestCard(visitId: visitId, isDoctor: isDoctor)
              : _LabPollingCard(labRequestId: labRequest.labRequestId),
        ),
        const SizedBox(height: 24),

        // Continue — Doctor-only action.
        if (isDoctor) ...[
          FadeSlideIn(
            delay: const Duration(milliseconds: 240),
            child: AppButton(
              label: 'Continue to assessment',
              icon: Icons.arrow_forward_rounded,
              onPressed: readyForAssessment
                  ? () => context.go('/assessment?visit=$visitId')
                  : null,
            ),
          ),
          if (labReady && !visit.hasVitals)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Record vitals above before continuing to assessment.',
                style: text.labelSmall?.copyWith(color: AppTheme.inkMuted),
              ),
            ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

/// BP and heart rate — the doctor measures these themself rather than
/// sending them to the lab (only cholesterol and blood glucose are
/// requestable from the lab; height/weight are captured once by
/// Reception at registration). Editable any time, so a doctor can
/// correct a value even after saving.
class _VitalsCard extends ConsumerStatefulWidget {
  final String visitId;
  final Visit visit;

  const _VitalsCard({required this.visitId, required this.visit});

  @override
  ConsumerState<_VitalsCard> createState() => _VitalsCardState();
}

class _VitalsCardState extends ConsumerState<_VitalsCard> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    _controllers = {
      'systolic_bp': TextEditingController(text: v.systolicBp?.toString()),
      'diastolic_bp': TextEditingController(text: v.diastolicBp?.toString()),
      'heart_rate': TextEditingController(text: v.heartRate?.toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(visitActionsProvider).saveVitals(
            visitId: widget.visitId,
            systolicBp: int.parse(_controllers['systolic_bp']!.text.trim()),
            diastolicBp: int.parse(_controllers['diastolic_bp']!.text.trim()),
            heartRate: int.parse(_controllers['heart_rate']!.text.trim()),
          );
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Vitals saved.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(
              friendlyError(e, 'Could not save vitals — check the backend connection.'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
                title: 'Vitals', icon: Icons.monitor_heart_outlined),
            Text(
              'Blood pressure and heart rate — measured by you, not sent '
              'to the lab.',
              style: text.bodySmall?.copyWith(color: AppTheme.inkMuted),
            ),
            const SizedBox(height: 8),
            for (final k in VitalsCatalog.all)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: _controllers[k],
                  keyboardType: TextInputType.numberWithOptions(
                      decimal: !LabTestCatalog.isWholeNumber(k)),
                  inputFormatters: [
                    if (LabTestCatalog.isWholeNumber(k))
                      FilteringTextInputFormatter.digitsOnly
                    else
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                  ],
                  decoration: InputDecoration(
                    labelText: '${LabTestCatalog.label(k)} *',
                    suffixText: LabTestCatalog.unit(k),
                    prefixIcon: Icon(LabTestCatalog.icon(k)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return double.tryParse(v.trim()) == null
                        ? 'Enter a number'
                        : null;
                  },
                ),
              ),
            const SizedBox(height: 8),
            AppButton(
              label: widget.visit.hasVitals ? 'Update vitals' : 'Save vitals',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoLabRequestCard extends StatelessWidget {
  final String visitId;
  final bool isDoctor;

  const _NoLabRequestCard({required this.visitId, required this.isDoctor});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: 'Lab tests', icon: Icons.science_outlined),
          Text(
            isDoctor
                ? 'No lab tests have been requested for this visit yet. '
                    'Request the tests you need before running the stroke '
                    'risk assessment.'
                : 'No lab tests have been requested for this visit yet.',
            style: text.bodyMedium?.copyWith(color: AppTheme.inkSecondary),
          ),
          if (isDoctor) ...[
            const SizedBox(height: 16),
            AppButton(
              label: 'Request lab tests',
              icon: Icons.add_task_rounded,
              onPressed: () => context.go('/visits/$visitId/lab-request'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read-only vitals display for non-doctor viewers (e.g. Receptionist
/// reviewing a previous visit from a patient's profile).
class _VitalsSummaryCard extends StatelessWidget {
  final Visit visit;

  const _VitalsSummaryCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <String, String>{
      'Blood pressure': visit.systolicBp != null && visit.diastolicBp != null
          ? '${visit.systolicBp}/${visit.diastolicBp} mmHg'
          : 'Not yet recorded',
      'Heart rate':
          visit.heartRate != null ? '${visit.heartRate} bpm' : 'Not yet recorded',
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: 'Vitals', icon: Icons.monitor_heart_outlined),
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
                  Text(e.value,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LabPollingCard extends ConsumerWidget {
  final String labRequestId;

  const _LabPollingCard({required this.labRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final pollAsync = ref.watch(labRequestPollingProvider(labRequestId));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: 'Lab tests', icon: Icons.science_outlined),
          pollAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, st) => Text('Could not load lab status.',
                style: text.bodySmall?.copyWith(color: AppTheme.inkMuted)),
            data: (labDetail) {
              final request = labDetail.request;
              final result = labDetail.result;
              if (request.status != LabRequestStatus.completed) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LiveDot(color: AppTheme.riskMedium),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.status == LabRequestStatus.inProgress
                                ? 'Lab is working on the requested tests…'
                                : 'Waiting for the lab to pick up this request…',
                            style: text.bodyMedium
                                ?.copyWith(color: AppTheme.inkSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in request.requestedTests)
                          PillTag(
                              label: LabTestCatalog.label(t),
                              icon: LabTestCatalog.icon(t)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This page checks for results automatically every '
                      'few seconds.',
                      style: text.labelSmall
                          ?.copyWith(color: AppTheme.inkMuted),
                    ),
                  ],
                );
              }

              // Completed — show the synced findings, each tagged with its
              // reference range and flagged if outside it (workflow doc §3).
              final rows = <String, ({String value, String test, double? raw})>{
                if (result?.bloodGlucose != null)
                  'Blood glucose': (
                    value: '${LabTestCatalog.format('blood_glucose', result!.bloodGlucose!)} mmol/L',
                    test: 'blood_glucose',
                    raw: result.bloodGlucose,
                  ),
                if (result?.cholesterol != null)
                  'Cholesterol': (
                    value: '${LabTestCatalog.format('cholesterol', result!.cholesterol!)} mmol/L',
                    test: 'cholesterol',
                    raw: result.cholesterol,
                  ),
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppTheme.riskLow),
                      const SizedBox(width: 8),
                      Text('Results ready',
                          style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.riskLow)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final e in rows.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.key,
                                    style: text.bodySmall
                                        ?.copyWith(color: AppTheme.inkMuted)),
                                if (LabTestCatalog.referenceRange(e.value.test)
                                    .isNotEmpty)
                                  Text(
                                    'Normal: ${LabTestCatalog.referenceRange(e.value.test)}',
                                    style: text.labelSmall?.copyWith(
                                        color: AppTheme.inkMuted, fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                          Text(e.value.value,
                              style: text.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          if (e.value.raw != null &&
                              (e.value.test == 'bmi'
                                  ? true
                                  : LabTestCatalog.isAbnormal(
                                      e.value.test, e.value.raw!))) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.warning_rounded,
                                size: 15, color: AppTheme.riskHigh),
                          ],
                        ],
                      ),
                    ),
                  if (result?.labNotes != null &&
                      result!.labNotes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Lab notes',
                        style: text.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(result.labNotes!,
                        style: text.bodySmall
                            ?.copyWith(color: AppTheme.inkSecondary)),
                  ],
                  if (result != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Submitted by ${result.performedBy} · '
                      '${DateFormat('d MMM yyyy, HH:mm').format(result.submittedAt)}',
                      style: text.labelSmall
                          ?.copyWith(color: AppTheme.inkMuted),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
