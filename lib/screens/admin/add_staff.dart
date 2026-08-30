import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../models/staff.dart';
import '../../providers/staff_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

/// Admin-only: create a staff account of any role (POST /auth/register).
/// There is no public self-registration flow in this app.
class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _hospital = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  StaffRole _role = StaffRole.receptionist;
  bool _saving = false;

  static const _service = AuthService();

  @override
  void dispose() {
    for (final c in [_staffId, _name, _email, _hospital, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.createStaff(
        staffId: _staffId.text.trim(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: _role,
        hospital: _hospital.text.trim().isEmpty ? null : _hospital.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        password: _password.text,
      );
      ref.invalidate(staffListProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${_name.text.trim()} added as ${_role.label}.')),
      );
      context.go('/admin/staff');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Could not create the account — check the details and backend connection.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/admin/staff')),
        title: const Text('Add Staff'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: FadeSlideIn(
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader(
                          title: 'Role', icon: Icons.badge_outlined),
                      DropdownButtonFormField<StaffRole>(
                        initialValue: _role,
                        decoration:
                            const InputDecoration(labelText: 'Staff role'),
                        items: [
                          for (final r in StaffRole.values)
                            DropdownMenuItem(
                              value: r,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(r.icon, size: 18, color: r.color),
                                  const SizedBox(width: 10),
                                  Text(r.label),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _role = v ?? StaffRole.receptionist),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeader(
                          title: 'Account details',
                          icon: Icons.person_outline_rounded),
                      TextFormField(
                        controller: _staffId,
                        decoration: const InputDecoration(
                          labelText: 'Staff ID',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) =>
                            v != null && v.trim().isNotEmpty
                                ? null
                                : 'Enter a staff ID',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => v != null && v.trim().length >= 3
                            ? null
                            : 'Enter the staff member\'s name',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (v) =>
                            v != null && v.contains('@') && v.contains('.')
                                ? null
                                : 'Enter a valid email',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _hospital,
                              decoration: const InputDecoration(
                                labelText: 'Hospital (optional)',
                                prefixIcon:
                                    Icon(Icons.local_hospital_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone (optional)',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SectionHeader(
                          title: 'Login credentials',
                          icon: Icons.lock_outline_rounded),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporary password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) => v != null && v.length >= 6
                            ? null
                            : 'At least 6 characters',
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Create account',
                        icon: Icons.check_rounded,
                        loading: _saving,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
