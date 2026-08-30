import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lab_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_provider.dart';
import '../../widgets/ui_kit.dart';

/// Pending + in-progress lab requests, tap to open the submission form.
class LabQueueScreen extends ConsumerWidget {
  const LabQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labScientist = ref.watch(authProvider).currentUser;
    final queueAsync = ref.watch(labQueueProvider(null));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                        style: text.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .7),
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Karibu, ${labScientist?.name ?? 'Lab'}',
                        style: text.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                GradientAvatar(name: labScientist?.name ?? 'Lab', radius: 22),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(labQueueProvider(null)),
              child: queueAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, st) => ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.error_outline_rounded,
                      message: 'Could not load the lab queue',
                      hint: 'Pull down to try again.',
                    ),
                  ],
                ),
                data: (requests) {
                  final sorted = [...requests]
                    ..sort(
                        (a, b) => a.requestDate.compareTo(b.requestDate));
                  return ListView(
                    padding: const EdgeInsets.all(AppConstants.pagePadding),
                    children: [
                      Text(
                        '${sorted.length} request${sorted.length == 1 ? '' : 's'} pending',
                        style: text.labelMedium?.copyWith(
                            color: AppTheme.inkMuted, letterSpacing: .3),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < sorted.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(
                            delay:
                                Duration(milliseconds: 40 * (i > 8 ? 8 : i)),
                            child: _LabRequestRow(request: sorted[i]),
                          ),
                        ),
                      if (sorted.isEmpty)
                        const EmptyState(
                          icon: Icons.task_alt_rounded,
                          message: 'No pending lab requests',
                          hint: 'New requests from doctors show up here.',
                        ),
                      const SizedBox(height: 80),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabRequestRow extends StatelessWidget {
  final LabRequest request;

  const _LabRequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.go('/lab/${request.labRequestId}'),
      child: Row(
        children: [
          GradientAvatar(
              name: request.patientName ?? request.patientId, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.patientName ?? request.patientId,
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in request.requestedTests)
                      PillTag(label: LabTestCatalog.label(t)),
                  ],
                ),
              ],
            ),
          ),
          PillTag(
            label: request.status.label,
            icon: request.status.icon,
            color: request.status.color,
            background: request.status.color.withValues(alpha: .12),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.inkMuted),
        ],
      ),
    );
  }
}
