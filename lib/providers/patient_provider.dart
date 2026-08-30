import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/patient.dart';
import '../services/api_service.dart';

class PatientNotifier extends Notifier<List<Patient>> {
  @override
  List<Patient> build() {
    // Serve the cache instantly, refresh from the backend right after.
    Future.microtask(_load);
    return apiService.patients;
  }

  Future<void> _load() async {
    try {
      state = await apiService.fetchPatients();
    } catch (_) {
      // Backend unreachable — keep whatever is cached.
    }
  }

  Future<void> refresh() => _load();

  Future<void> addPatient(Patient patient) async {
    await apiService.addPatient(patient);
    state = apiService.patients;
  }

  Future<void> deletePatient(String patientId) async {
    await apiService.deletePatient(patientId);
    state = apiService.patients;
  }
}

final patientListProvider =
    NotifierProvider<PatientNotifier, List<Patient>>(PatientNotifier.new);

/// Search query typed on the patient management page.
class PatientSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final patientSearchQueryProvider =
    NotifierProvider<PatientSearchQuery, String>(PatientSearchQuery.new);

/// Patients filtered by ID, name, or phone.
final filteredPatientsProvider = Provider<List<Patient>>((ref) {
  final patients = ref.watch(patientListProvider);
  final q = ref.watch(patientSearchQueryProvider).toLowerCase().trim();
  if (q.isEmpty) return patients;
  return patients
      .where((p) =>
          p.id.toLowerCase().contains(q) ||
          p.name.toLowerCase().contains(q) ||
          p.phone.replaceAll(' ', '').contains(q.replaceAll(' ', '')))
      .toList();
});

/// Global patient search (GET /patients/search/{query}) — searches every
/// patient regardless of who registered them or who they're assigned to.
/// Used by Reception so a returning patient registered by a *different*
/// receptionist can still be found instead of accidentally re-registered
/// under a new patient_id.
final patientSearchResultsProvider =
    FutureProvider.family<List<Patient>, String>((ref, query) {
  return apiService.searchPatients(query);
});

final patientByIdProvider = Provider.family<Patient?, String>((ref, id) {
  final patients = ref.watch(patientListProvider);
  for (final p in patients) {
    if (p.id == id) return p;
  }
  return null;
});
