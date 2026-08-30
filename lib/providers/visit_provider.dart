import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/visit.dart';
import '../services/api_service.dart';

/// Today's front-desk visit board, or a specific [date] if provided.
final visitQueueProvider =
    FutureProvider.family<List<Visit>, DateTime?>((ref, date) {
  return apiService.fetchVisitQueue(date: date);
});

/// Args for [doctorQueueProvider]: a doctor's own assigned queue, with an
/// optional status filter ("my patients today").
typedef DoctorQueueArgs = ({String doctorId, String? status});

final doctorQueueProvider =
    FutureProvider.family<List<Visit>, DoctorQueueArgs>((ref, args) {
  return apiService.fetchDoctorQueue(args.doctorId, status: args.status);
});

/// Full visit detail: patient + assigned doctor + lab request.
final visitDetailProvider =
    FutureProvider.family<VisitDetail, String>((ref, visitId) {
  return apiService.fetchVisitDetail(visitId);
});

/// A patient's full visit history, most recent first — what the Doctor
/// reviews during the initial assessment (workflow doc §5).
final patientVisitsProvider =
    FutureProvider.family<List<Visit>, String>((ref, patientId) {
  return apiService.fetchPatientVisits(patientId);
});

/// Creates visits and assigns doctors, then invalidates the queues that
/// depend on the result so lists refresh in place.
class VisitActions {
  const VisitActions(this.ref);
  final Ref ref;

  Future<Visit> createVisit({
    required String patientId,
    DateTime? visitDate,
    DateTime? arrivalTime,
  }) async {
    final visit = await apiService.createVisit(
      patientId: patientId,
      visitDate: visitDate,
      arrivalTime: arrivalTime,
    );
    ref.invalidate(visitQueueProvider);
    return visit;
  }

  Future<Visit> assignDoctor({
    required String visitId,
    required String doctorId,
  }) async {
    final visit =
        await apiService.assignDoctor(visitId: visitId, doctorId: doctorId);
    ref.invalidate(visitQueueProvider);
    ref.invalidate(visitDetailProvider(visitId));
    return visit;
  }

  Future<Visit> reassessPatient(String patientId) async {
    final visit = await apiService.reassessPatient(patientId);
    ref.invalidate(visitQueueProvider);
    ref.invalidate(patientVisitsProvider(patientId));
    return visit;
  }

  /// Doctor saves their own BP/heart-rate vitals for a visit.
  Future<Visit> saveVitals({
    required String visitId,
    required int systolicBp,
    required int diastolicBp,
    required int heartRate,
  }) async {
    final visit = await apiService.saveVitals(
      visitId: visitId,
      systolicBp: systolicBp,
      diastolicBp: diastolicBp,
      heartRate: heartRate,
    );
    ref.invalidate(visitDetailProvider(visitId));
    return visit;
  }
}

final visitActionsProvider = Provider<VisitActions>((ref) => VisitActions(ref));
