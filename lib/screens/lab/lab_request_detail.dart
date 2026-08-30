import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lab_request.dart';
import '../../providers/lab_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

/// Submission form for a lab request — only shows the fields the doctor
/// actually asked for (cholesterol and/or blood glucose), with a
/// review-before-submit confirmation.
class LabRequestDetailScreen extends ConsumerStatefulWidget {
  final String labRequestId;

  const LabRequestDetailScreen({super.key, required this.labRequestId});

  @override
  ConsumerState<LabRequestDetailScreen> createState() =>
      _LabRequestDetailScreenState();
}

class _LabRequestDetailScreenState
    extends ConsumerState<LabRequestDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final t in LabTestCatalog.all) t: TextEditingController(),
  };
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final c in _controllers.values) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _reviewAndSubmit(LabRequestDetail detail) async {
    if (!_formKey.currentState!.validate()) return;
    final values = <String, double?>{
      for (final t in detail.request.requestedTests)
        t: double.tryParse(_controllers[t]!.text.trim()),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in detail.request.requestedTests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(LabTestCatalog.label(t))),
                    Text(
                      values[t] != null
                          ? '${LabTestCatalog.format(t, values[t]!)} ${LabTestCatalog.unit(t)}'
                          : 'Not entered',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: values[t] != null
                            ? AppTheme.inkPrimary
                            : AppTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await apiService.submitLabResult(
        labRequestId: widget.labRequestId,
        bloodGlucose: values['blood_glucose'],
        cholesterol: values['cholesterol'],
        labNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      ref.invalidate(labQueueProvider(null));
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Lab results submitted.')));
      context.go('/lab');
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(friendlyError(
              e, 'Could not submit results — check the backend connection.'))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(labRequestDetailProvider(widget.labRequestId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/lab')),
        title: const Text('Lab Request'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            message: 'Could not load this request',
            hint: 'Check the backend connection and try again.',
          ),
        ),
        data: (detail) {
          final alreadyDone =
              detail.request.status == LabRequestStatus.completed;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              PillTag(
                                label: detail.request.status.label,
                                icon: detail.request.status.icon,
                                color: detail.request.status.color,
                                background: detail.request.status.color
                                    .withValues(alpha: .12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.cardGap),
                      if (alreadyDone)
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 100),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader(
                                    title: 'Already submitted',
                                    icon: Icons.check_circle_outline_rounded),
                                Text(
                                  'Results for this request were already '
                                  'submitted by ${detail.result?.performedBy ?? 'the lab'}.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppTheme.inkSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 100),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader(
                                    title: 'Requested tests',
                                    icon: Icons.science_outlined),
                                for (final t in detail.request.requestedTests)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: TextFormField(
                                      controller: _controllers[t],
                                      keyboardType: TextInputType.numberWithOptions(
                                          decimal: !LabTestCatalog.isWholeNumber(t)),
                                      inputFormatters: [
                                        if (LabTestCatalog.isWholeNumber(t))
                                          FilteringTextInputFormatter.digitsOnly
                                        else
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d*\.?\d*$')),
                                      ],
                                      decoration: InputDecoration(
                                        labelText: '${LabTestCatalog.label(t)} *',
                                        suffixText: LabTestCatalog.unit(t),
                                        prefixIcon:
                                            Icon(LabTestCatalog.icon(t)),
                                      ),
                                      // Every field shown here was explicitly
                                      // requested by the doctor, so — unlike a
                                      // patient's optional history fields —
                                      // these are required before the lab
                                      // scientist can submit (doc §7: "Enters
                                      // all findings into the system").
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Required';
                                        }
                                        return double.tryParse(v.trim()) ==
                                                null
                                            ? 'Enter a number'
                                            : null;
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.cardGap),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 180),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionHeader(
                                    title: 'Notes',
                                    icon: Icons.edit_note_rounded),
                                TextFormField(
                                  controller: _notes,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Any observations for the doctor…',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Review & submit',
                          icon: Icons.fact_check_outlined,
                          loading: _submitting,
                          onPressed: () => _reviewAndSubmit(detail),
                        ),
                      ],
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
