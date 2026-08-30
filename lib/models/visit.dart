import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'lab_request.dart';
import 'patient.dart';
import 'staff.dart';

enum VisitStatus {
  waitingAssignment,
  assigned,
  awaitingLab,
  labCompleted,
  completed,
  cancelled,
}

extension VisitStatusX on VisitStatus {
  String get wireValue => switch (this) {
        VisitStatus.waitingAssignment => 'waiting_assignment',
        VisitStatus.assigned => 'assigned',
        VisitStatus.awaitingLab => 'awaiting_lab',
        VisitStatus.labCompleted => 'lab_completed',
        VisitStatus.completed => 'completed',
        VisitStatus.cancelled => 'cancelled',
      };

  static VisitStatus fromWire(String value) => switch (value) {
        'waiting_assignment' => VisitStatus.waitingAssignment,
        'assigned' => VisitStatus.assigned,
        'awaiting_lab' => VisitStatus.awaitingLab,
        'lab_completed' => VisitStatus.labCompleted,
        'completed' => VisitStatus.completed,
        'cancelled' => VisitStatus.cancelled,
        _ => throw ArgumentError('Unknown visit status: $value'),
      };

  String get label => switch (this) {
        VisitStatus.waitingAssignment => 'Waiting Assignment',
        VisitStatus.assigned => 'Assigned',
        VisitStatus.awaitingLab => 'Awaiting Lab',
        VisitStatus.labCompleted => 'Lab Completed',
        VisitStatus.completed => 'Completed',
        VisitStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        VisitStatus.waitingAssignment => AppTheme.riskMedium,
        VisitStatus.assigned => AppTheme.primaryGreen,
        VisitStatus.awaitingLab => AppTheme.midGreen,
        VisitStatus.labCompleted => AppTheme.deepGreen,
        VisitStatus.completed => AppTheme.riskLow,
        VisitStatus.cancelled => AppTheme.riskHigh,
      };

  IconData get icon => switch (this) {
        VisitStatus.waitingAssignment => Icons.hourglass_empty_rounded,
        VisitStatus.assigned => Icons.person_pin_circle_rounded,
        VisitStatus.awaitingLab => Icons.science_outlined,
        VisitStatus.labCompleted => Icons.fact_check_outlined,
        VisitStatus.completed => Icons.check_circle_rounded,
        VisitStatus.cancelled => Icons.cancel_rounded,
      };
}

class Visit {
  final String visitId;
  final String patientId;
  final DateTime visitDate;
  final DateTime arrivalTime;
  final VisitStatus status;
  final String createdBy;
  final String? assignedDoctorId;
  final DateTime? assignedAt;
  final DateTime createdAt;

  /// Vitals the doctor measures themself — null until they've saved
  /// them via the visit's "Vitals" card. Height/weight are recorded
  /// once by Reception at patient registration instead (see Patient).
  final int? systolicBp;
  final int? diastolicBp;
  final int? heartRate;

  const Visit({
    required this.visitId,
    required this.patientId,
    required this.visitDate,
    required this.arrivalTime,
    required this.status,
    required this.createdBy,
    this.assignedDoctorId,
    this.assignedAt,
    required this.createdAt,
    this.systolicBp,
    this.diastolicBp,
    this.heartRate,
  });

  /// True once the doctor has recorded all of their own vitals for this
  /// visit — required (alongside the lab result) before an assessment
  /// can be run.
  bool get hasVitals =>
      systolicBp != null && diastolicBp != null && heartRate != null;

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        visitId: json['visit_id'] as String,
        patientId: json['patient_id'] as String,
        visitDate: DateTime.parse(json['visit_date'] as String),
        arrivalTime: DateTime.parse(json['arrival_time'] as String),
        status: VisitStatusX.fromWire(json['status'] as String),
        createdBy: json['created_by'] as String,
        assignedDoctorId: json['assigned_doctor_id'] as String?,
        assignedAt: json['assigned_at'] == null
            ? null
            : DateTime.parse(json['assigned_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        systolicBp: (json['systolic_bp'] as num?)?.toInt(),
        diastolicBp: (json['diastolic_bp'] as num?)?.toInt(),
        heartRate: (json['heart_rate'] as num?)?.toInt(),
      );
}

/// Full visit detail: the visit plus the joined patient, assigned doctor,
/// and lab request (all nullable per the backend contract).
class VisitDetail {
  final Visit visit;
  final Patient patient;
  final Staff? assignedDoctor;
  final LabRequest? labRequest;

  const VisitDetail({
    required this.visit,
    required this.patient,
    this.assignedDoctor,
    this.labRequest,
  });

  factory VisitDetail.fromJson(Map<String, dynamic> json) => VisitDetail(
        visit: Visit.fromJson(json),
        patient: Patient.fromJson(json['patient'] as Map<String, dynamic>),
        assignedDoctor: json['assigned_doctor'] == null
            ? null
            : Staff.fromJson(json['assigned_doctor'] as Map<String, dynamic>),
        labRequest: json['lab_request'] == null
            ? null
            : LabRequest.fromJson(json['lab_request'] as Map<String, dynamic>),
      );
}
