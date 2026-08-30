import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report.dart';
import '../services/api_service.dart';

/// Monthly vitals trend for the Reports tab's monitoring charts
/// (GET /reports/{patient_id}).
final patientReportProvider =
    FutureProvider.family<PatientReport, String>((ref, patientId) {
  return apiService.fetchReport(patientId);
});
