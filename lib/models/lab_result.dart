class LabResult {
  final String labResultId;
  final String labRequestId;
  final String visitId;
  final String patientId;
  final String performedBy;
  final double? bloodGlucose;
  final double? cholesterol;
  final String? labNotes;
  final DateTime submittedAt;

  const LabResult({
    required this.labResultId,
    required this.labRequestId,
    required this.visitId,
    required this.patientId,
    required this.performedBy,
    this.bloodGlucose,
    this.cholesterol,
    this.labNotes,
    required this.submittedAt,
  });

  factory LabResult.fromJson(Map<String, dynamic> json) => LabResult(
        labResultId: json['lab_result_id'] as String,
        labRequestId: json['lab_request_id'] as String,
        visitId: json['visit_id'] as String,
        patientId: json['patient_id'] as String,
        performedBy: json['performed_by'] as String,
        bloodGlucose: (json['blood_glucose'] as num?)?.toDouble(),
        cholesterol: (json['cholesterol'] as num?)?.toDouble(),
        labNotes: json['lab_notes'] as String?,
        submittedAt: DateTime.parse(json['submitted_at'] as String),
      );
}
