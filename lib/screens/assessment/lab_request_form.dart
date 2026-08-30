import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/lab_request.dart';
import '../../providers/visit_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

/// Doctor picks which of the fixed set of tests the lab should perform
/// for this visit (POST /lab/requests).
class LabRequestFormScreen extends ConsumerStatefulWidget {
  final String visitId;

  const LabRequestFormScreen({super.key, required this.visitId});

  @override
  ConsumerState<LabRequestFormScreen> createState() =>
      _LabRequestFormScreenState();
}

class _LabRequestFormScreenState extends ConsumerState<LabRequestFormScreen> {
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await apiService.createLabRequest(
        visitId: widget.visitId,
        requestedTests: _selected.toList(),
      );
      ref.invalidate(visitDetailProvider(widget.visitId));
      if (mounted) context.go('/visits/${widget.visitId}');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Could not send the lab request — check the backend connection.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            onPressed: () => context.go('/visits/${widget.visitId}')),
        title: const Text('Request Lab Tests'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FadeSlideIn(
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                        title: 'Select tests', icon: Icons.checklist_rounded),
                    Text(
                      'Choose the tests the lab should perform for this '
                      'visit. Only the fields you select will appear on '
                      'the lab scientist\'s submission form.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    for (final t in LabTestCatalog.all)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppTheme.primaryGreen,
                        value: _selected.contains(t),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(t);
                          } else {
                            _selected.remove(t);
                          }
                        }),
                        secondary: Icon(LabTestCatalog.icon(t),
                            color: AppTheme.primaryGreen),
                        title: Text(LabTestCatalog.label(t)),
                        subtitle: Text(LabTestCatalog.unit(t)),
                      ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Send to lab',
                      icon: Icons.send_rounded,
                      loading: _saving,
                      onPressed: _selected.isEmpty ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
