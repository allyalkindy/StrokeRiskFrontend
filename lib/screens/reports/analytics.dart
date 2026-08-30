import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/prediction.dart';
import '../../models/report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/chart_widget.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  /// Pre-selected patient (from the profile page), if any.
  final String? patientId;

  const AnalyticsScreen({super.key, this.patientId});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _patientId;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
  }

  Future<void> _exportPdf(String patientId) async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await apiService.downloadReportPdf(patientId);
      messenger.showSnackBar(
        SnackBar(content: Text('Report downloaded: $patientId.pdf')),
      );
      await OpenFilex.open(path);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content:
              Text('Could not export the PDF — check the backend connection.')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = _patientId;

    return Scaffold(
      appBar: AppBar(
        leading: patientId == null
            ? null
            : BackButton(onPressed: () => setState(() => _patientId = null)),
        automaticallyImplyLeading: patientId != null,
        title: const Text('Analytics & Reports'),
        actions: [
          if (patientId != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AppButton(
                label: 'Export PDF',
                icon: Icons.picture_as_pdf_outlined,
                outlined: true,
                expanded: false,
                loading: _exporting,
                onPressed: _exporting ? null : () => _exportPdf(patientId),
              ),
            ),
        ],
      ),
      body: patientId == null
          ? _AssessedPatientsList(
              onSelect: (id) => setState(() => _patientId = id))
          : _PatientReportView(
              patientId: patientId,
              onChangePatient: (id) => setState(() => _patientId = id),
            ),
    );
  }
}

/// Landing state for the Reports tab reached with no `?patient=` param:
/// only the patients *this* doctor has personally assessed (a prediction
/// run on a visit assigned to them), not every patient in the system.
class _AssessedPatientsList extends ConsumerWidget {
  final void Function(String patientId) onSelect;

  const _AssessedPatientsList({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(authProvider).currentUser;
    final text = Theme.of(context).textTheme;
    if (doctor == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final predictionsAsync =
        ref.watch(predictionsByDoctorProvider(doctor.staffId));

    return predictionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          message: 'Could not load your reports',
          hint: 'Check the backend connection and try again.',
        ),
      ),
      data: (predictions) {
        // Latest assessment per patient — backend already orders by date.
        final latest = <String, Prediction>{};
        for (final p in predictions) {
          latest[p.patientId] = p;
        }
        final rows = latest.values.toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        if (rows.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.insights_rounded,
              message: 'No assessed patients yet',
              hint:
                  'Patients you\'ve run a stroke risk assessment for appear here.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          children: [
            Text(
              '${rows.length} assessed patient${rows.length == 1 ? '' : 's'}',
              style: text.labelMedium
                  ?.copyWith(color: AppTheme.inkMuted, letterSpacing: .3),
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  for (final pr in rows) ...[
                    _ReportRow(prediction: pr, onTap: onSelect),
                    if (pr != rows.last) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReportRow extends ConsumerWidget {
  final Prediction prediction;
  final void Function(String patientId) onTap;

  const _ReportRow({required this.prediction, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientByIdProvider(prediction.patientId));
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTap(prediction.patientId),
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
            RiskChip(level: prediction.riskLevel, compact: true),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// The dropdown + charts + PDF export view for one patient. The dropdown
/// is scoped to only patients *this doctor* has actually assessed — same
/// scope as the landing list — so it can't wander into an unassessed
/// patient's empty, data-less charts.
class _PatientReportView extends ConsumerWidget {
  final String patientId;
  final void Function(String patientId) onChangePatient;

  const _PatientReportView(
      {required this.patientId, required this.onChangePatient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(authProvider).currentUser;
    final predictionsAsync = doctor == null
        ? const AsyncValue<List<Prediction>>.data(<Prediction>[])
        : ref.watch(predictionsByDoctorProvider(doctor.staffId));

    return predictionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          message: 'Could not load your reports',
          hint: 'Check the backend connection and try again.',
        ),
      ),
      data: (predictions) {
        final ids = <String>{for (final p in predictions) p.patientId};
        // Safety net: keep the currently-open patient selectable even if
        // it somehow isn't in the assessed set yet (e.g. a stale cache
        // right after the very first assessment for them) — otherwise
        // the dropdown's initialValue wouldn't match any item.
        ids.add(patientId);
        final labels = {
          for (final id in ids) id: ref.watch(patientByIdProvider(id))?.name ?? id,
        };
        final sortedIds = ids.toList()
          ..sort((a, b) => labels[a]!.compareTo(labels[b]!));

        return ListView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          children: [
            FadeSlideIn(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusField),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: patientId,
                    decoration: const InputDecoration(
                      labelText: 'Patient',
                      prefixIcon: Icon(Icons.person_search_rounded),
                    ),
                    items: [
                      for (final id in sortedIds)
                        DropdownMenuItem(
                          value: id,
                          child: Text('${labels[id]} ($id)'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) onChangePatient(v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.cardGap),
            _AnalyticsCharts(patientId: patientId),
          ],
        );
      },
    );
  }
}

class _AnalyticsCharts extends ConsumerWidget {
  final String patientId;

  const _AnalyticsCharts({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(predictionHistoryProvider(patientId)).value ?? const [];

    final riskValues = [
      for (final p in history) p.probability * 100
    ];
    final riskLabels = [
      for (final p in history) DateFormat('MMM').format(p.date)
    ];

    // One measure per chart — different scales never share an axis. Risk
    // history is real prediction data; the vitals trends below are real
    // monthly averages from GET /reports/{patient_id} (each _VitalChartCard
    // watches that independently, so a slow/failed fetch doesn't block the
    // other charts).
    final charts = <Widget>[
      ChartCard(
        title: 'Stroke risk history',
        subtitle: 'Predicted probability per assessment (%)',
        child: riskValues.isEmpty
            ? Center(
                child: Text('No assessments yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.inkMuted)))
            : AppLineChart(
                values: riskValues,
                xLabels: riskLabels,
                unit: '%',
                minY: 0,
                maxY: 100,
              ),
      ),
      _VitalChartCard(
        patientId: patientId,
        title: 'Systolic blood pressure',
        subtitle: 'Monthly average (mmHg)',
        pick: (m) => m.avgSystolicBp,
        color: AppTheme.deepGreen,
      ),
      _VitalChartCard(
        patientId: patientId,
        title: 'Cholesterol',
        subtitle: 'Monthly average (mmol/L)',
        pick: (m) => m.avgCholesterol,
        color: AppTheme.midGreen,
      ),
      _VitalChartCard(
        patientId: patientId,
        title: 'Blood glucose',
        subtitle: 'Monthly average (mmol/L)',
        pick: (m) => m.avgBloodSugar,
      ),
      _VitalChartCard(
        patientId: patientId,
        title: 'Resting heart rate',
        subtitle: 'Monthly average (BPM)',
        pick: (m) => m.avgHeartRate,
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 2 : 1;
      final w = (c.maxWidth - (cols - 1) * AppConstants.cardGap) / cols;
      return Wrap(
        spacing: AppConstants.cardGap,
        runSpacing: AppConstants.cardGap,
        children: [
          for (var i = 0; i < charts.length; i++)
            SizedBox(
              width: w,
              child: FadeSlideIn(
                delay: Duration(milliseconds: 80 * i),
                child: charts[i],
              ),
            ),
        ],
      );
    });
  }
}

/// One monthly-average vitals trend chart, sourced from
/// GET /reports/{patient_id}. Owns its own async state so one slow/failed
/// metric doesn't block the rest of the grid.
class _VitalChartCard extends ConsumerWidget {
  final String patientId;
  final String title;
  final String subtitle;
  final double? Function(MonthlyVital) pick;
  final Color color;

  const _VitalChartCard({
    required this.patientId,
    required this.title,
    required this.subtitle,
    required this.pick,
    this.color = AppTheme.primaryGreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(patientReportProvider(patientId));
    final mutedText = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: AppTheme.inkMuted);

    return ChartCard(
      title: title,
      subtitle: subtitle,
      child: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text('Could not load this chart.', style: mutedText)),
        data: (report) {
          final values = <double>[];
          final labels = <String>[];
          for (final m in report.monthlyVitals) {
            final v = pick(m);
            if (v == null) continue;
            values.add(v);
            labels.add(DateFormat('MMM').format(DateTime.parse('${m.month}-01')));
          }
          if (values.isEmpty) {
            return Center(child: Text('No data yet.', style: mutedText));
          }
          return AppLineChart(values: values, xLabels: labels, color: color);
        },
      ),
    );
  }
}
