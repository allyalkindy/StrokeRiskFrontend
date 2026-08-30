import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/network/api_client.dart';
import '../models/lab_request.dart';
import '../models/lab_result.dart';
import '../models/patient.dart';
import '../models/prediction.dart';
import '../models/recommendation.dart';
import '../models/report.dart';
import '../models/sms_log.dart';
import '../models/staff.dart';
import '../models/visit.dart';

/// Data layer for patients, visits, lab work, predictions,
/// recommendations, and staff — real HTTP calls to the FastAPI backend.
///
/// Keeps small in-memory caches so screens that need synchronous reads
/// (e.g. the patient list filter) stay fast between fetches.
class ApiService {
  ApiService();

  final List<Patient> _patients = [];
  final Map<String, List<Prediction>> _history = {};

  List<Patient> get patients => List.unmodifiable(_patients);

  // ── Patients ────────────────────────────────────────────────────
  Future<List<Patient>> fetchPatients() async {
    final res = await ApiClient.dio.get('/patients');
    _patients
      ..clear()
      ..addAll([
        for (final j in res.data as List)
          Patient.fromJson(j as Map<String, dynamic>)
      ]);
    return patients;
  }

  Future<Patient> addPatient(Patient patient) async {
    final res = await ApiClient.dio.post('/patients', data: patient.toJson());
    final created = Patient.fromJson(res.data as Map<String, dynamic>);
    _patients.add(created);
    return created;
  }

  Future<Patient> fetchPatient(String patientId) async {
    final res = await ApiClient.dio.get('/patients/$patientId');
    return Patient.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Patient>> searchPatients(String query) async {
    if (query.trim().isEmpty) return fetchPatients();
    final res = await ApiClient.dio
        .get('/patients/search/${Uri.encodeComponent(query.trim())}');
    return [
      for (final j in res.data as List)
        Patient.fromJson(j as Map<String, dynamic>)
    ];
  }

  Future<void> deletePatient(String patientId) async {
    await ApiClient.dio.delete('/patients/$patientId');
    _patients.removeWhere((p) => p.id == patientId);
    _history.remove(patientId);
  }

  // ── Visits ──────────────────────────────────────────────────────
  Future<Visit> createVisit({
    required String patientId,
    DateTime? visitDate,
    DateTime? arrivalTime,
  }) async {
    final res = await ApiClient.dio.post('/visits', data: {
      'patient_id': patientId,
      if (visitDate != null) 'visit_date': visitDate.toIso8601String(),
      if (arrivalTime != null) 'arrival_time': arrivalTime.toIso8601String(),
    });
    return Visit.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Visit> assignDoctor({
    required String visitId,
    required String doctorId,
  }) async {
    final res = await ApiClient.dio.put(
      '/visits/$visitId/assign',
      data: {'doctor_id': doctorId},
    );
    return Visit.fromJson(res.data as Map<String, dynamic>);
  }

  /// Doctor self-service follow-up: only succeeds if this doctor has
  /// already completed at least one prior visit with this patient.
  Future<Visit> reassessPatient(String patientId) async {
    final res = await ApiClient.dio.post('/visits/$patientId/reassess');
    return Visit.fromJson(res.data as Map<String, dynamic>);
  }

  /// Front-desk board — every visit for [date] (default today).
  Future<List<Visit>> fetchVisitQueue({DateTime? date}) async {
    final res = await ApiClient.dio.get('/visits/queue', queryParameters: {
      if (date != null)
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    });
    return [
      for (final j in res.data as List) Visit.fromJson(j as Map<String, dynamic>)
    ];
  }

  /// "My patients today" — a doctor's assigned queue.
  Future<List<Visit>> fetchDoctorQueue(
    String doctorId, {
    String? status,
  }) async {
    final res = await ApiClient.dio.get(
      '/visits/doctor/$doctorId/queue',
      queryParameters: {'status': ?status},
    );
    return [
      for (final j in res.data as List) Visit.fromJson(j as Map<String, dynamic>)
    ];
  }

  Future<VisitDetail> fetchVisitDetail(String visitId) async {
    final res = await ApiClient.dio.get('/visits/$visitId');
    return VisitDetail.fromJson(res.data as Map<String, dynamic>);
  }

  /// A patient's full visit history, most recent first.
  Future<List<Visit>> fetchPatientVisits(String patientId) async {
    final res = await ApiClient.dio.get('/visits/patient/$patientId');
    return [
      for (final j in res.data as List) Visit.fromJson(j as Map<String, dynamic>)
    ];
  }

  /// Doctor records their own BP/heart-rate vitals for a visit — height
  /// and weight are captured once by Reception at registration instead.
  Future<Visit> saveVitals({
    required String visitId,
    required int systolicBp,
    required int diastolicBp,
    required int heartRate,
  }) async {
    final res = await ApiClient.dio.put(
      '/visits/$visitId/vitals',
      data: {
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
        'heart_rate': heartRate,
      },
    );
    return Visit.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Lab ─────────────────────────────────────────────────────────
  Future<LabRequest> createLabRequest({
    required String visitId,
    required List<String> requestedTests,
  }) async {
    final res = await ApiClient.dio.post('/lab/requests', data: {
      'visit_id': visitId,
      'requested_tests': requestedTests,
    });
    return LabRequest.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<LabRequest>> fetchLabQueue({String? status}) async {
    final res = await ApiClient.dio.get(
      '/lab/requests/queue',
      queryParameters: {'status': ?status},
    );
    return [
      for (final j in res.data as List)
        LabRequest.fromJson(j as Map<String, dynamic>)
    ];
  }

  Future<LabRequestDetail> fetchLabRequestDetail(String labRequestId) async {
    final res = await ApiClient.dio.get('/lab/requests/$labRequestId');
    return LabRequestDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<LabResult> submitLabResult({
    required String labRequestId,
    double? bloodGlucose,
    double? cholesterol,
    String? labNotes,
  }) async {
    final res = await ApiClient.dio.put(
      '/lab/requests/$labRequestId/submit',
      data: {
        'blood_glucose': bloodGlucose,
        'cholesterol': cholesterol,
        'lab_notes': labNotes,
      },
    );
    return LabResult.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Staff (admin) ───────────────────────────────────────────────
  Future<List<Staff>> fetchStaff() async {
    final res = await ApiClient.dio.get('/staff');
    return [
      for (final j in res.data as List) Staff.fromJson(j as Map<String, dynamic>)
    ];
  }

  Future<Staff> deactivateStaff(String staffId) async {
    final res = await ApiClient.dio.put('/staff/$staffId/deactivate');
    return Staff.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Staff> activateStaff(String staffId) async {
    final res = await ApiClient.dio.put('/staff/$staffId/activate');
    return Staff.fromJson(res.data as Map<String, dynamic>);
  }

  /// Active doctors only — feeds the receptionist's "assign doctor" picker.
  Future<List<Staff>> fetchDoctors() async {
    final res = await ApiClient.dio.get('/staff/doctors');
    return [
      for (final j in res.data as List) Staff.fromJson(j as Map<String, dynamic>)
    ];
  }

  // ── Prediction ──────────────────────────────────────────────────
  Future<Prediction> analyzeStrokeRisk(AssessmentInput input) async {
    final res =
        await ApiClient.dio.post('/prediction/analyze', data: input.toJson());
    final prediction = Prediction.fromJson(res.data as Map<String, dynamic>);
    _history.putIfAbsent(prediction.patientId, () => []).add(prediction);
    return prediction;
  }

  Future<List<Prediction>> fetchHistory(String patientId) async {
    final res = await ApiClient.dio.get('/prediction/history/$patientId');
    final list = [
      for (final j in res.data as List)
        Prediction.fromJson(j as Map<String, dynamic>)
    ];
    _history[patientId] = list;
    return list;
  }

  /// Cached history (latest fetch); prefer [fetchHistory] for fresh data.
  List<Prediction> historyFor(String patientId) =>
      List.unmodifiable(_history[patientId] ?? const []);

  /// Every prediction run on a visit assigned to [doctorId] — powers the
  /// doctor's Reports tab (only their own assessed patients).
  Future<List<Prediction>> fetchPredictionsByDoctor(String doctorId) async {
    final res = await ApiClient.dio.get('/prediction/doctor/$doctorId/patients');
    return [
      for (final j in res.data as List)
        Prediction.fromJson(j as Map<String, dynamic>)
    ];
  }

  Future<void> deletePrediction(String patientId, String predictionId) async {
    await ApiClient.dio.delete('/prediction/$predictionId');
    _history[patientId]?.removeWhere((p) => p.id == predictionId);
  }

  // ── Reports ─────────────────────────────────────────────────────
  /// Monthly vitals trend behind the Reports tab's monitoring charts.
  Future<PatientReport> fetchReport(String patientId) async {
    final res = await ApiClient.dio.get('/reports/$patientId');
    return PatientReport.fromJson(res.data as Map<String, dynamic>);
  }

  /// Downloads the branded PDF health report and returns the local
  /// file path (GET /reports/{patient_id}/pdf).
  Future<String> downloadReportPdf(String patientId) async {
    final res = await ApiClient.dio.get<List<int>>(
      '/reports/$patientId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/StrokeGuard_$patientId.pdf');
    await file.writeAsBytes(res.data!);
    return file.path;
  }

  // ── Recommendations ─────────────────────────────────────────────
  Future<List<Recommendation>> fetchRecommendations(String patientId) async {
    final res = await ApiClient.dio.get('/recommendations/$patientId');
    return [
      for (final j in res.data as List)
        Recommendation.fromJson(j as Map<String, dynamic>)
    ];
  }

  Future<Recommendation> approveRecommendation({
    required String recommendationId,
    List<int>? acceptedIndices,
    String? doctorAdvice,
  }) async {
    final res = await ApiClient.dio.put('/recommendations/approve', data: {
      'recommendation_id': recommendationId,
      'accepted_indices': acceptedIndices,
      'doctor_advice': doctorAdvice,
    });
    return Recommendation.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Recommendation> rejectRecommendation({
    required String recommendationId,
    String? doctorAdvice,
  }) async {
    final res = await ApiClient.dio.put('/recommendations/reject', data: {
      'recommendation_id': recommendationId,
      'doctor_advice': doctorAdvice,
    });
    return Recommendation.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SmsLog> sendRecommendationSms(String recommendationId) async {
    final res = await ApiClient.dio
        .post('/recommendations/$recommendationId/send-sms', data: {});
    return SmsLog.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<SmsLog>> fetchSmsLog(String recommendationId) async {
    final res =
        await ApiClient.dio.get('/recommendations/$recommendationId/sms-log');
    return [
      for (final j in res.data as List) SmsLog.fromJson(j as Map<String, dynamic>)
    ];
  }
}

/// Single shared instance so every screen sees the same caches.
final apiService = ApiService();
