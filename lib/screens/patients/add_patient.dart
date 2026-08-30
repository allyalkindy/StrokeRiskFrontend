import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/error_message.dart';
import '../../core/theme/app_theme.dart';
import '../../models/patient.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/health_card.dart';
import '../../widgets/ui_kit.dart';

class AddPatientScreen extends ConsumerStatefulWidget {
  const AddPatientScreen({super.key});

  @override
  ConsumerState<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends ConsumerState<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController(
      text: 'PT-${1000 + DateTime.now().millisecondsSinceEpoch % 9000}');
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _history = TextEditingController();
  String _gender = 'Female';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Live BMI preview as height/weight are typed.
    _height.addListener(() => setState(() {}));
    _weight.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_id, _name, _age, _phone, _height, _weight, _history]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _bmiPreview {
    final h = double.tryParse(_height.text.trim());
    final w = double.tryParse(_weight.text.trim());
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final patient = Patient(
      id: _id.text.trim(),
      name: _name.text.trim(),
      age: int.parse(_age.text),
      gender: _gender,
      phone: _phone.text.trim(),
      height: double.parse(_height.text.trim()),
      weight: double.parse(_weight.text.trim()),
      medicalHistory: _history.text.trim(),
    );
    try {
      await ref.read(patientListProvider.notifier).addPatient(patient);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${patient.name} registered.')),
      );
      context.go('/patients/${patient.id}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(friendlyError(e,
            'Could not register the patient — check the backend connection.')),
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/patients')),
        title: const Text('Register Patient'),
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
                          title: 'Personal information',
                          icon: Icons.person_outline_rounded),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _id,
                              decoration: const InputDecoration(
                                  labelText: 'Patient ID'),
                              validator: (v) =>
                                  v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration:
                                  const InputDecoration(labelText: 'Gender'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Female', child: Text('Female')),
                                DropdownMenuItem(
                                    value: 'Male', child: Text('Male')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _gender = v ?? 'Female'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        validator: (v) => v!.trim().length >= 3
                            ? null
                            : 'Enter the patient\'s name',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _age,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Age', suffixText: 'yrs'),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                return n != null && n > 0 && n < 130
                                    ? null
                                    : 'Invalid age';
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Phone number',
                                  hintText: '+255 …'),
                              validator: (v) => v!.trim().length >= 9
                                  ? null
                                  : 'Enter a valid phone',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _height,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$')),
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Height', suffixText: 'cm'),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                return n != null && n > 50 && n < 260
                                    ? null
                                    : 'Invalid height';
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _weight,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$')),
                              ],
                              decoration: const InputDecoration(
                                  labelText: 'Weight', suffixText: 'kg'),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                return n != null && n > 10 && n < 400
                                    ? null
                                    : 'Invalid weight';
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_bmiPreview != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.monitor_weight_outlined,
                                size: 18, color: AppTheme.primaryGreen),
                            const SizedBox(width: 8),
                            Text(
                              'BMI: ${_bmiPreview!.toStringAsFixed(1)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      const SectionHeader(
                          title: 'Medical history',
                          icon: Icons.medical_information_outlined),
                      TextFormField(
                        controller: _history,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Hypertension, diabetes, family history of stroke…',
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Register patient',
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
