import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recommendation.dart';
import '../../models/sms_log.dart';
import '../../providers/patient_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

class RecommendationReviewScreen extends ConsumerStatefulWidget {
  final String patientId;

  const RecommendationReviewScreen({super.key, required this.patientId});

  @override
  ConsumerState<RecommendationReviewScreen> createState() =>
      _RecommendationReviewScreenState();
}

class _RecommendationReviewScreenState
    extends ConsumerState<RecommendationReviewScreen> {
  final _advice = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild as the doctor types so the Approve button's enabled state
    // (which considers free-text advice when there's no AI advice) stays
    // in sync.
    _advice.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _advice.dispose();
    super.dispose();
  }

  String _actionError(String fallback) {
    final error = ref.read(recommendationReviewProvider).lastError;
    return error == null ? fallback : friendlyError(error, fallback);
  }

  Future<void> _approve() async {
    ref.read(recommendationReviewProvider.notifier).setDoctorAdvice(_advice.text.trim());
    final ok = await ref.read(recommendationReviewProvider.notifier).approve();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Recommendations approved. Send them to the patient by SMS when ready.'
          : _actionError('Approval failed — check the backend connection.')),
    ));
  }

  Future<void> _reject() async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Reject recommendations?',
      message:
          'The AI suggestions for this assessment will be marked rejected '
          'and will not be sent to the patient.',
      confirmLabel: 'Reject',
    );
    if (!confirmed) return;
    ref.read(recommendationReviewProvider.notifier).setDoctorAdvice(_advice.text.trim());
    final ok = await ref.read(recommendationReviewProvider.notifier).reject();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Recommendations rejected.'
          : _actionError('Could not reject — check the backend connection.')),
    ));
  }

  Future<void> _sendSms() async {
    final ok = await ref.read(recommendationReviewProvider.notifier).sendSms();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Recommendations sent to the patient by SMS.'
          : _actionError('Could not send SMS — check the backend connection.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(recommendationsProvider(widget.patientId));
    final review = ref.watch(recommendationReviewProvider);
    final patient = ref.watch(patientByIdProvider(widget.patientId));
    final text = Theme.of(context).textTheme;

    // The newest recommendation for this patient is the one under review.
    // Load it into the review notifier as soon as the list arrives (or
    // refreshes with a new one).
    ref.listen(recommendationsProvider(widget.patientId), (prev, next) {
      final list = next.value;
      if (list == null || list.isEmpty) return;
      final current = ref.read(recommendationReviewProvider).recommendation;
      if (current == null || current.recommendationId != list.first.recommendationId) {
        ref.read(recommendationReviewProvider.notifier).loadFrom(list.first);
        _advice.text = list.first.doctorAdvice ?? '';
      }
    });

    final recommendation = review.recommendation;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/dashboard')),
        title: const Text('Recommendation Review'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            message: 'Could not load recommendations',
            hint: 'Check the backend connection and try again.',
          ),
        ),
        data: (list) {
          if (list.isEmpty || recommendation == null) {
            return const Center(
              child: EmptyState(
                icon: Icons.tips_and_updates_outlined,
                message: 'No recommendations yet',
                hint: 'Run an assessment first.',
              ),
            );
          }

          final isPending =
              recommendation.approvalStatus == ApprovalStatus.pending;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              GradientAvatar(
                                  name: patient?.name ?? widget.patientId,
                                  radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(patient?.name ?? widget.patientId,
                                        style: text.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPending
                                          ? 'Uncheck any suggestion you disagree with, '
                                              'add your own advice, then approve or reject.'
                                          : 'This recommendation has already been reviewed.',
                                      style: text.bodySmall?.copyWith(
                                          color: AppTheme.inkMuted),
                                    ),
                                  ],
                                ),
                              ),
                              PillTag(
                                label: recommendation.approvalStatus.label,
                                icon: recommendation.approvalStatus.icon,
                                color: recommendation.approvalStatus.color,
                                background: recommendation.approvalStatus.color
                                    .withValues(alpha: .12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                                title: 'AI suggestions',
                                icon: Icons.tips_and_updates_outlined),
                            if (recommendation.aiAdvice.isEmpty)
                              Text('No AI suggestions for this assessment.',
                                  style: text.bodyMedium
                                      ?.copyWith(color: AppTheme.inkMuted)),
                            for (var i = 0;
                                i < recommendation.aiAdvice.length;
                                i++)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                activeColor: AppTheme.primaryGreen,
                                value: review.accepted.contains(i),
                                onChanged: !isPending
                                    ? null
                                    : (_) => ref
                                        .read(recommendationReviewProvider
                                            .notifier)
                                        .toggle(i),
                                title: Text(recommendation.aiAdvice[i]),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.cardGap),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                                title: 'Additional doctor advice',
                                icon: Icons.edit_note_rounded),
                            TextField(
                              controller: _advice,
                              maxLines: 4,
                              enabled: isPending,
                              decoration: const InputDecoration(
                                hintText:
                                    'e.g. Schedule a follow-up visit in 2 weeks; start BP log…',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (recommendation.approvalStatus ==
                        ApprovalStatus.approved) ...[
                      const SizedBox(height: AppConstants.cardGap),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 260),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(
                                  title: 'Send to patient',
                                  icon: Icons.sms_outlined),
                              Text(
                                'Notify the patient of the approved '
                                'recommendations by SMS.',
                                style: text.bodySmall
                                    ?.copyWith(color: AppTheme.inkMuted),
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: 'Send by SMS',
                                icon: Icons.send_rounded,
                                outlined: true,
                                loading: review.sendingSms,
                                onPressed: _sendSms,
                              ),
                              if (review.lastSms != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    PillTag(
                                      label:
                                          'SMS ${review.lastSms!.status.label}',
                                      icon: review.lastSms!.status.icon,
                                      color: review.lastSms!.status.color,
                                      background: review.lastSms!.status.color
                                          .withValues(alpha: .12),
                                    ),
                                  ],
                                ),
                                if (review.lastSms!.failureReason != null) ...[
                                  const SizedBox(height: 6),
                                  Text(review.lastSms!.failureReason!,
                                      style: text.bodySmall?.copyWith(
                                          color: AppTheme.riskHigh)),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isPending)
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            AppButton(
                              label: 'Approve',
                              icon: Icons.verified_rounded,
                              loading: review.submitting,
                              onPressed: recommendation.aiAdvice.isEmpty &&
                                      _advice.text.trim().isEmpty
                                  ? null
                                  : _approve,
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              label: 'Reject',
                              icon: Icons.cancel_outlined,
                              outlined: true,
                              loading: review.submitting,
                              onPressed: _reject,
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
