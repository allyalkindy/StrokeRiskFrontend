import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'lab_result.dart';
import 'patient.dart';

/// The fixed set of tests a doctor may request from the lab. Everything
/// else the catalog knows about (BP, height, weight, heart rate) is
/// measured by the doctor themself — see `VitalsCatalog` below — but the
/// label/unit/icon/reference-range helpers here stay generic by key so
/// both catalogs can share them.
class LabTestCatalog {
  LabTestCatalog._();

  static const List<String> all = [
    'blood_glucose',
    'cholesterol',
  ];

  static String label(String key) => switch (key) {
        'systolic_bp' => 'Systolic BP',
        'diastolic_bp' => 'Diastolic BP',
        'blood_glucose' => 'Blood Glucose',
        'cholesterol' => 'Cholesterol',
        'height' => 'Height',
        'weight' => 'Weight',
        'heart_rate' => 'Heart Rate',
        _ => key,
      };

  static String unit(String key) => switch (key) {
        'systolic_bp' => 'mmHg',
        'diastolic_bp' => 'mmHg',
        'blood_glucose' => 'mmol/L',
        'cholesterol' => 'mmol/L',
        'height' => 'cm',
        'weight' => 'kg',
        'heart_rate' => 'bpm',
        _ => '',
      };

  static IconData icon(String key) => switch (key) {
        'systolic_bp' || 'diastolic_bp' => Icons.monitor_heart_outlined,
        'blood_glucose' => Icons.bloodtype_outlined,
        'cholesterol' => Icons.science_outlined,
        'height' => Icons.straighten_rounded,
        'weight' => Icons.monitor_weight_outlined,
        'heart_rate' => Icons.favorite_outline_rounded,
        _ => Icons.biotech_outlined,
      };

  /// Systolic/diastolic BP and heart rate are whole numbers on the
  /// backend (`int`) — a fractional value like "152.5" fails Pydantic
  /// validation with a 422. Everything else is a `float` and may carry
  /// a decimal.
  static bool isWholeNumber(String key) =>
      key == 'systolic_bp' || key == 'diastolic_bp' || key == 'heart_rate';

  static int decimalsFor(String key) => isWholeNumber(key) ? 0 : 1;

  static String format(String key, double value) =>
      value.toStringAsFixed(decimalsFor(key));

  /// Typical adult reference range, shown next to a synced result so the
  /// Doctor can tell at a glance whether a value needs attention.
  static String referenceRange(String key) => switch (key) {
        'systolic_bp' => '90–120 mmHg',
        'diastolic_bp' => '60–80 mmHg',
        'blood_glucose' => '4.0–5.9 mmol/L (fasting)',
        'cholesterol' => '< 5.2 mmol/L',
        'heart_rate' => '60–100 bpm (resting)',
        _ => '',
      };

  /// Mirrors the clinical thresholds the backend's rule engine uses
  /// (recommendation/rules.py) so the "abnormal" flag the Doctor sees
  /// here agrees with the risk factors the prediction later reports.
  static bool isAbnormal(String key, double value) => switch (key) {
        'systolic_bp' => value >= 140 || value < 90,
        'diastolic_bp' => value >= 90 || value < 60,
        'blood_glucose' => value >= 7.0,
        'cholesterol' => value >= 6.2,
        'heart_rate' => value > 100,
        _ => false,
      };
}

/// The vitals the doctor measures themself for a visit — BP and heart
/// rate. Height/weight are recorded once by Reception at patient
/// registration instead. Shares LabTestCatalog's label/unit/icon/
/// reference-range/abnormal-flag helpers since they're keyed generically.
class VitalsCatalog {
  VitalsCatalog._();

  static const List<String> all = [
    'systolic_bp',
    'diastolic_bp',
    'heart_rate',
  ];
}

enum LabRequestStatus { pending, inProgress, completed, cancelled }

extension LabRequestStatusX on LabRequestStatus {
  String get wireValue => switch (this) {
        LabRequestStatus.pending => 'pending',
        LabRequestStatus.inProgress => 'in_progress',
        LabRequestStatus.completed => 'completed',
        LabRequestStatus.cancelled => 'cancelled',
      };

  static LabRequestStatus fromWire(String value) => switch (value) {
        'pending' => LabRequestStatus.pending,
        'in_progress' => LabRequestStatus.inProgress,
        'completed' => LabRequestStatus.completed,
        'cancelled' => LabRequestStatus.cancelled,
        _ => throw ArgumentError('Unknown lab request status: $value'),
      };

  String get label => switch (this) {
        LabRequestStatus.pending => 'Pending',
        LabRequestStatus.inProgress => 'In Progress',
        LabRequestStatus.completed => 'Completed',
        LabRequestStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        LabRequestStatus.pending => AppTheme.riskMedium,
        LabRequestStatus.inProgress => AppTheme.primaryGreen,
        LabRequestStatus.completed => AppTheme.riskLow,
        LabRequestStatus.cancelled => AppTheme.riskHigh,
      };

  IconData get icon => switch (this) {
        LabRequestStatus.pending => Icons.hourglass_empty_rounded,
        LabRequestStatus.inProgress => Icons.pending_actions_rounded,
        LabRequestStatus.completed => Icons.check_circle_rounded,
        LabRequestStatus.cancelled => Icons.cancel_rounded,
      };
}

class LabRequest {
  final String labRequestId;
  final String visitId;
  final String patientId;
  final String requestedBy;
  final List<String> requestedTests;
  final LabRequestStatus status;
  final DateTime requestDate;

  /// Flattened convenience field present only on `GET /lab/requests/queue`
  /// list items — null elsewhere.
  final String? patientName;

  const LabRequest({
    required this.labRequestId,
    required this.visitId,
    required this.patientId,
    required this.requestedBy,
    required this.requestedTests,
    required this.status,
    required this.requestDate,
    this.patientName,
  });

  factory LabRequest.fromJson(Map<String, dynamic> json) => LabRequest(
        labRequestId: json['lab_request_id'] as String,
        visitId: json['visit_id'] as String,
        patientId: json['patient_id'] as String,
        requestedBy: json['requested_by'] as String,
        requestedTests: List<String>.from(json['requested_tests'] as List),
        status: LabRequestStatusX.fromWire(json['status'] as String),
        requestDate: DateTime.parse(json['request_date'] as String),
        patientName: json['patient_name'] as String?,
      );
}

class LabRequestDetail {
  final LabRequest request;
  final Patient patient;
  final LabResult? result;

  const LabRequestDetail({
    required this.request,
    required this.patient,
    this.result,
  });

  factory LabRequestDetail.fromJson(Map<String, dynamic> json) =>
      LabRequestDetail(
        request: LabRequest.fromJson(json),
        patient: Patient.fromJson(json['patient'] as Map<String, dynamic>),
        result: json['result'] == null
            ? null
            : LabResult.fromJson(json['result'] as Map<String, dynamic>),
      );
}
