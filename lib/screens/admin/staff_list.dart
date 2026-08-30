import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/ui_kit.dart';

/// Admin staff directory: search, activate/deactivate, and view details.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  String _query = '';

  void _viewStaff(Staff staff) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => _StaffDetailSheet(staff: staff),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.buttonGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.glow(AppTheme.primaryGreen),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.go('/admin/staff/add'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add staff'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(staffListProvider.notifier).refresh(),
        child: staffAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, st) => ListView(
            children: const [
              SizedBox(height: 120),
              EmptyState(
                icon: Icons.error_outline_rounded,
                message: 'Could not load staff',
                hint: 'Pull down to try again.',
              ),
            ],
          ),
          data: (allStaff) {
            final q = _query.toLowerCase().trim();
            final filtered = q.isEmpty
                ? allStaff
                : allStaff
                    .where((s) =>
                        s.name.toLowerCase().contains(q) ||
                        s.staffId.toLowerCase().contains(q) ||
                        s.email.toLowerCase().contains(q) ||
                        s.role.label.toLowerCase().contains(q))
                    .toList();

            return ListView(
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusField),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name, ID, email, or role…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${filtered.length} staff member${filtered.length == 1 ? '' : 's'}',
                  style: text.labelMedium?.copyWith(
                    color: AppTheme.inkMuted,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < filtered.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeSlideIn(
                      delay: Duration(milliseconds: 40 * (i > 8 ? 8 : i)),
                      child: _StaffRow(
                        staff: filtered[i],
                        onTap: () => _viewStaff(filtered[i]),
                      ),
                    ),
                  ),
                if (filtered.isEmpty)
                  const EmptyState(
                    icon: Icons.people_outline_rounded,
                    message: 'No staff match your search',
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

class _StaffRow extends ConsumerWidget {
  final Staff staff;
  final VoidCallback onTap;

  const _StaffRow({required this.staff, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          GradientAvatar(name: staff.name, radius: 25),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff.name,
                    style:
                        text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  '${staff.staffId} · ${staff.email}',
                  style: text.bodySmall?.copyWith(color: AppTheme.inkMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    PillTag(
                      label: staff.role.label,
                      icon: staff.role.icon,
                      color: staff.role.color,
                      background: staff.role.color.withValues(alpha: .12),
                    ),
                    PillTag(
                      label: staff.active ? 'Active' : 'Inactive',
                      icon: staff.active
                          ? Icons.check_circle_rounded
                          : Icons.pause_circle_outline_rounded,
                      color: staff.active
                          ? AppTheme.riskLow
                          : AppTheme.inkMuted,
                      background: (staff.active
                              ? AppTheme.riskLow
                              : AppTheme.inkMuted)
                          .withValues(alpha: .12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: staff.active,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref
                  .read(staffListProvider.notifier)
                  .setActive(staff.staffId, v);
              if (!ok) {
                messenger.showSnackBar(SnackBar(
                    content: Text(
                        'Could not ${v ? 'activate' : 'deactivate'} ${staff.name}.')));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StaffDetailSheet extends StatelessWidget {
  final Staff staff;

  const _StaffDetailSheet({required this.staff});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = <String, String>{
      'Staff ID': staff.staffId,
      'Email': staff.email,
      'Role': staff.role.label,
      if (staff.hospital != null && staff.hospital!.isNotEmpty)
        'Hospital': staff.hospital!,
      if (staff.phone != null && staff.phone!.isNotEmpty)
        'Phone': staff.phone!,
      'Status': staff.active ? 'Active' : 'Inactive',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GradientAvatar(name: staff.name, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.name,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(staff.role.label,
                        style:
                            text.bodySmall?.copyWith(color: AppTheme.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(e.key,
                        style: text.bodySmall
                            ?.copyWith(color: AppTheme.inkMuted)),
                  ),
                  Expanded(
                    child: Text(e.value,
                        style: text.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
