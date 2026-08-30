import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum ApprovalStatus { pending, approved, rejected }

extension ApprovalStatusX on ApprovalStatus {
  String get wireValue => switch (this) {
        ApprovalStatus.pending => 'pending',
        ApprovalStatus.approved => 'approved',
        ApprovalStatus.rejected => 'rejected',
      };

  static ApprovalStatus fromWire(String value) => switch (value) {
        'pending' => ApprovalStatus.pending,
        'approved' => ApprovalStatus.approved,
        'rejected' => ApprovalStatus.rejected,
        _ => throw ArgumentError('Unknown approval status: $value'),
      };

  String get label => switch (this) {
        ApprovalStatus.pending => 'Pending review',
        ApprovalStatus.approved => 'Approved',
        ApprovalStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        ApprovalStatus.pending => AppTheme.riskMedium,
        ApprovalStatus.approved => AppTheme.riskLow,
        ApprovalStatus.rejected => AppTheme.riskHigh,
      };

  IconData get icon => switch (this) {
        ApprovalStatus.pending => Icons.hourglass_empty_rounded,
        ApprovalStatus.approved => Icons.verified_rounded,
        ApprovalStatus.rejected => Icons.cancel_rounded,
      };
}

class Recommendation {
  final String recommendationId;
  final String patientId;
  final String predictionId;
  final List<String> aiAdvice;
  final String? doctorAdvice;
  final ApprovalStatus approvalStatus;
  final String? approvedBy;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const Recommendation({
    required this.recommendationId,
    required this.patientId,
    required this.predictionId,
    required this.aiAdvice,
    this.doctorAdvice,
    required this.approvalStatus,
    this.approvedBy,
    this.reviewedAt,
    this.approvedAt,
    required this.createdAt,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) =>
      Recommendation(
        recommendationId: json['recommendation_id'] as String,
        patientId: json['patient_id'] as String,
        predictionId: json['prediction_id'] as String,
        aiAdvice: List<String>.from(json['ai_advice'] as List? ?? []),
        doctorAdvice: json['doctor_advice'] as String?,
        approvalStatus: ApprovalStatusX.fromWire(
            json['approval_status'] as String? ?? 'pending'),
        approvedBy: json['approved_by'] as String?,
        reviewedAt: json['reviewed_at'] == null
            ? null
            : DateTime.parse(json['reviewed_at'] as String),
        approvedAt: json['approved_at'] == null
            ? null
            : DateTime.parse(json['approved_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
