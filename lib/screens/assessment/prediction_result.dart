import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/prediction.dart';
import '../../providers/patient_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

class PredictionResultScreen extends ConsumerWidget {
  const PredictionResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prediction = ref.watch(predictionProvider).current;
    final text = Theme.of(context).textTheme;

    if (prediction == null) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go('/assessment')),
          title: const Text('Prediction Result'),
        ),
        body: const Center(
          child: EmptyState(
            icon: Icons.online_prediction_rounded,
            message: 'No prediction yet',
            hint: 'Run an assessment first.',
          ),
        ),
      );
    }

    final patient = ref.watch(patientByIdProvider(prediction.patientId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/assessment')),
        title: const Text('Prediction Result'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero result card — animated ring; icon + label + number,
                // color never alone.
                FadeSlideIn(
                  child: AppCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        if (patient != null)
                          Text(
                            '${patient.name} · ${patient.id}',
                            style: text.bodyMedium
                                ?.copyWith(color: AppTheme.inkMuted),
                          ),
                        const SizedBox(height: 24),
                        _AnimatedRiskRing(
                          probability: prediction.probability,
                          color: prediction.riskLevel.color,
                        ),
                        const SizedBox(height: 24),
                        RiskChip(level: prediction.riskLevel),
                        const SizedBox(height: 12),
                        Text(
                          'Estimated probability of stroke based on the '
                          'submitted clinical and lifestyle factors.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall
                              ?.copyWith(color: AppTheme.inkMuted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (prediction.modelVersion.isNotEmpty)
                              PillTag(
                                label: 'Model ${prediction.modelVersion}',
                                icon: Icons.memory_rounded,
                              ),
                            PillTag(
                              label: DateFormat('d MMM yyyy, HH:mm')
                                  .format(prediction.date),
                              icon: Icons.schedule_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.cardGap),

                // Synced values this prediction was computed from.
                FadeSlideIn(
                  delay: const Duration(milliseconds: 100),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: 'Based on',
                            icon: Icons.fact_check_outlined),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (prediction.systolicBp != null &&
                                prediction.diastolicBp != null)
                              PillTag(
                                label:
                                    'BP ${prediction.systolicBp!.toStringAsFixed(0)}/${prediction.diastolicBp!.toStringAsFixed(0)}',
                                icon: Icons.monitor_heart_outlined,
                              ),
                            if (prediction.bloodGlucose != null)
                              PillTag(
                                label:
                                    'Glucose ${prediction.bloodGlucose!.toStringAsFixed(1)}',
                                icon: Icons.bloodtype_outlined,
                              ),
                            if (prediction.cholesterol != null)
                              PillTag(
                                label:
                                    'Cholesterol ${prediction.cholesterol!.toStringAsFixed(1)}',
                                icon: Icons.science_outlined,
                              ),
                            if (prediction.bmi != null)
                              PillTag(
                                label: 'BMI ${prediction.bmi!.toStringAsFixed(1)}',
                                icon: Icons.monitor_weight_outlined,
                              ),
                            if (prediction.heartRate != null)
                              PillTag(
                                label: 'HR ${prediction.heartRate}bpm',
                                icon: Icons.favorite_outline_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.cardGap),

                // Risk factors — every possible factor is listed; the ones
                // that applied to this patient add up to the total
                // probability shown above (e.g. sum to 24% if the result
                // was 24%), everything else sits at 0%.
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: 'Identified risk factors',
                            icon: Icons.report_problem_outlined),
                        for (final f in [...prediction.factorBreakdown]
                          ..sort(
                              (a, b) => b.percentage.compareTo(a.percentage)))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        f.factor,
                                        style: text.bodyMedium?.copyWith(
                                          fontWeight: f.percentage > 0
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: f.percentage > 0
                                              ? null
                                              : AppTheme.inkMuted,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${f.percentage.toStringAsFixed(0)}%',
                                      style: text.bodyMedium?.copyWith(
                                        fontWeight: f.percentage > 0
                                            ? FontWeight.w800
                                            : FontWeight.w400,
                                        color: f.percentage > 0
                                            ? AppTheme.riskHigh
                                            : AppTheme.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: f.percentage / 100,
                                    minHeight: 6,
                                    color: f.percentage > 0
                                        ? AppTheme.riskHigh
                                        : AppTheme.inkMuted.withValues(
                                            alpha: .3),
                                    backgroundColor: AppTheme.softMint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Each factor\'s share of the total probability '
                            'above — 0% means it wasn\'t present for this '
                            'patient.',
                            style: text.labelSmall
                                ?.copyWith(color: AppTheme.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.cardGap),

                // AI recommendations
                FadeSlideIn(
                  delay: const Duration(milliseconds: 250),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: 'AI lifestyle recommendations',
                            icon: Icons.tips_and_updates_outlined),
                        for (final r in prediction.aiRecommendations)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 20,
                                    color: AppTheme.primaryGreen),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(r, style: text.bodyMedium)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.softMint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_outlined,
                                  size: 18, color: AppTheme.deepGreen),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Recommendations require doctor approval '
                                  'before they are sent to the patient.',
                                  style: text.bodySmall?.copyWith(
                                      color: AppTheme.deepGreen),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                FadeSlideIn(
                  delay: const Duration(milliseconds: 350),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppButton(
                        label: 'Review & approve',
                        icon: Icons.fact_check_outlined,
                        onPressed: () => context
                            .go('/recommendations/${prediction.patientId}'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Generate PDF report',
                        icon: Icons.picture_as_pdf_outlined,
                        outlined: true,
                        onPressed: () => context
                            .go('/analytics?patient=${prediction.patientId}'),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Back to patient',
                        icon: Icons.person_rounded,
                        outlined: true,
                        onPressed: () =>
                            context.go('/patients/${prediction.patientId}'),
                      ),
                    ],
                  ),
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

/// Progress ring that sweeps up to the probability while the percentage
/// counts up in the middle.
class _AnimatedRiskRing extends StatelessWidget {
  final double probability;
  final Color color;

  const _AnimatedRiskRing({required this.probability, required this.color});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: probability),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 13,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AppTheme.softMint,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.inkPrimary,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'probability',
                  style:
                      text.labelSmall?.copyWith(color: AppTheme.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
