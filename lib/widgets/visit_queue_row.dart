import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/visit.dart';
import '../providers/patient_provider.dart';
import 'ui_kit.dart';

/// A single row in a doctor's visit queue — patient, arrival time, and
/// status badge, tapping through to the visit workspace. Shared between
/// the Home dashboard's "My patient queue" card and the standalone Queue
/// tab so the row UI isn't duplicated.
class VisitQueueRow extends ConsumerWidget {
  final Visit visit;

  const VisitQueueRow({super.key, required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientByIdProvider(visit.patientId));
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/visits/${visit.visitId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            GradientAvatar(
                name: patient?.name ?? visit.patientId, radius: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient?.name ?? visit.patientId,
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${visit.patientId} · arrived ${DateFormat('HH:mm').format(visit.arrivalTime)}',
                    style:
                        text.bodySmall?.copyWith(color: AppTheme.inkMuted),
                  ),
                ],
              ),
            ),
            if (visit.status == VisitStatus.assigned)
              IconButton(
                tooltip: 'Send to lab',
                icon: const Icon(Icons.biotech_rounded,
                    color: AppTheme.primaryGreen),
                onPressed: () =>
                    context.go('/visits/${visit.visitId}/lab-request'),
              ),
            PillTag(
              label: visit.status.label,
              icon: visit.status.icon,
              color: visit.status.color,
              background: visit.status.color.withValues(alpha: .12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.inkMuted),
          ],
        ),
      ),
    );
  }
}
