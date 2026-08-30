import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum RiskLevel { low, medium, high }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'Low Risk',
        RiskLevel.medium => 'Medium Risk',
        RiskLevel.high => 'High Risk',
      };

  /// Status color — always render beside [icon] and [label], never alone.
  Color get color => switch (this) {
        RiskLevel.low => AppTheme.riskLow,
        RiskLevel.medium => AppTheme.riskMedium,
        RiskLevel.high => AppTheme.riskHigh,
      };

  IconData get icon => switch (this) {
        RiskLevel.low => Icons.check_circle_rounded,
        RiskLevel.medium => Icons.error_rounded,
        RiskLevel.high => Icons.warning_rounded,
      };
}

/// A single risk factor's share of this prediction's rule-based score.
/// Normalized across only the factors that fired for this patient, so
/// [percentage] values sum to 100 across [Prediction.factorBreakdown].
class FactorContribution {
  final String factor;
  final double percentage; // 0..100

  const FactorContribution({required this.factor, required this.percentage});

  factory FactorContribution.fromJson(Map<String, dynamic> json) =>
      FactorContribution(
        factor: json['factor'] as String,
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class Prediction {
  final String id;
  final String patientId;
  final String visitId;
  final RiskLevel riskLevel;
  final double probability; // 0..1
  final List<String> riskFactors;
  final List<FactorContribution> factorBreakdown;
  final List<String> aiRecommendations;
  final String modelVersion;
  final DateTime date;

  // Synced clinical values this prediction was actually computed from
  // (resolved server-side from the visit's lab result) — shown
  // transparently on the result screen.
  final double? systolicBp;
  final double? diastolicBp;
  final double? bloodGlucose;
  final double? cholesterol;
  final double? bmi;
  final int? heartRate;

  const Prediction({
    required this.id,
    required this.patientId,
    required this.visitId,
    required this.riskLevel,
    required this.probability,
    required this.riskFactors,
    required this.factorBreakdown,
    required this.aiRecommendations,
    required this.modelVersion,
    required this.date,
    this.systolicBp,
    this.diastolicBp,
    this.bloodGlucose,
    this.cholesterol,
    this.bmi,
    this.heartRate,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        id: json['prediction_id'] as String,
        patientId: json['patient_id'] as String,
        visitId: json['visit_id'] as String,
        riskLevel: RiskLevel.values.byName(json['risk_level'] as String),
        probability: (json['probability'] as num).toDouble(),
        riskFactors: List<String>.from(json['risk_factors'] as List? ?? []),
        factorBreakdown: [
          for (final f in json['factor_breakdown'] as List? ?? [])
            FactorContribution.fromJson(f as Map<String, dynamic>)
        ],
        aiRecommendations:
            List<String>.from(json['ai_recommendations'] as List? ?? []),
        modelVersion: json['model_version'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        systolicBp: (json['systolic_bp'] as num?)?.toDouble(),
        diastolicBp: (json['diastolic_bp'] as num?)?.toDouble(),
        bloodGlucose: (json['blood_glucose'] as num?)?.toDouble(),
        cholesterol: (json['cholesterol'] as num?)?.toDouble(),
        bmi: (json['bmi'] as num?)?.toDouble(),
        heartRate: (json['heart_rate'] as num?)?.toInt(),
      );
}

/// Inputs collected on the Stroke Assessment page. The clinical numbers
/// (BP, glucose, cholesterol, BMI, heart rate) are no longer entered by
/// hand — the backend resolves them all from the visit's synced lab
/// result via [visitId].
class AssessmentInput {
  final String visitId;
  final bool heartDisease;
  final bool smoking;
  final bool alcohol;
  final String physicalActivity; // Low / Moderate / High
  final String diet; // Poor / Average / Healthy
  final bool familyHistory;

  const AssessmentInput({
    required this.visitId,
    required this.heartDisease,
    required this.smoking,
    required this.alcohol,
    required this.physicalActivity,
    required this.diet,
    required this.familyHistory,
  });

  Map<String, dynamic> toJson() => {
        'visit_id': visitId,
        'heart_disease': heartDisease,
        'smoking': smoking,
        'alcohol': alcohol,
        'physical_activity': physicalActivity,
        'diet': diet,
        'family_history': familyHistory,
      };
}
