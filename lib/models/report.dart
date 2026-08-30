/// One calendar month's averaged clinical values for a patient, sourced
/// from the resolved values logged at each assessment (GET
/// /reports/{patient_id}). BP/heart rate are the Doctor's own per-visit
/// vitals; cholesterol/blood sugar come from the Lab.
class MonthlyVital {
  final String month; // e.g. "2026-08"
  final double? avgHeartRate;
  final double? avgSystolicBp;
  final double? avgDiastolicBp;
  final double? avgCholesterol;
  final double? avgBloodSugar;

  const MonthlyVital({
    required this.month,
    this.avgHeartRate,
    this.avgSystolicBp,
    this.avgDiastolicBp,
    this.avgCholesterol,
    this.avgBloodSugar,
  });

  factory MonthlyVital.fromJson(Map<String, dynamic> json) => MonthlyVital(
        month: json['month'] as String,
        avgHeartRate: (json['avg_heart_rate'] as num?)?.toDouble(),
        avgSystolicBp: (json['avg_systolic_bp'] as num?)?.toDouble(),
        avgDiastolicBp: (json['avg_diastolic_bp'] as num?)?.toDouble(),
        avgCholesterol: (json['avg_cholesterol'] as num?)?.toDouble(),
        avgBloodSugar: (json['avg_blood_sugar'] as num?)?.toDouble(),
      );
}

/// GET /reports/{patient_id} — the monitoring data behind the Reports
/// tab's per-patient trend charts. Risk history and the latest snapshot
/// are already covered by [Prediction]/predictionHistoryProvider, so
/// only the monthly vitals trend is parsed here.
class PatientReport {
  final String patientId;
  final List<MonthlyVital> monthlyVitals;

  const PatientReport({required this.patientId, required this.monthlyVitals});

  factory PatientReport.fromJson(Map<String, dynamic> json) => PatientReport(
        patientId: json['patient_id'] as String,
        monthlyVitals: [
          for (final m in json['monthly_vitals'] as List? ?? [])
            MonthlyVital.fromJson(m as Map<String, dynamic>)
        ],
      );
}
