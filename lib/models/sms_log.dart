import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum SmsStatus { pending, sent, delivered, failed }

extension SmsStatusX on SmsStatus {
  String get wireValue => switch (this) {
        SmsStatus.pending => 'pending',
        SmsStatus.sent => 'sent',
        SmsStatus.delivered => 'delivered',
        SmsStatus.failed => 'failed',
      };

  static SmsStatus fromWire(String value) => switch (value) {
        'pending' => SmsStatus.pending,
        'sent' => SmsStatus.sent,
        'delivered' => SmsStatus.delivered,
        'failed' => SmsStatus.failed,
        _ => throw ArgumentError('Unknown SMS status: $value'),
      };

  String get label => switch (this) {
        SmsStatus.pending => 'Pending',
        SmsStatus.sent => 'Sent',
        SmsStatus.delivered => 'Delivered',
        SmsStatus.failed => 'Failed',
      };

  Color get color => switch (this) {
        SmsStatus.pending => AppTheme.riskMedium,
        SmsStatus.sent => AppTheme.primaryGreen,
        SmsStatus.delivered => AppTheme.riskLow,
        SmsStatus.failed => AppTheme.riskHigh,
      };

  IconData get icon => switch (this) {
        SmsStatus.pending => Icons.schedule_send_rounded,
        SmsStatus.sent => Icons.send_rounded,
        SmsStatus.delivered => Icons.mark_email_read_rounded,
        SmsStatus.failed => Icons.error_outline_rounded,
      };
}

class SmsLog {
  final String smsId;
  final String patientId;
  final String recommendationId;
  final String phone;
  final String message;
  final String sentBy;
  final String provider;
  final SmsStatus status;
  final String? failureReason;
  final DateTime sentAt;

  const SmsLog({
    required this.smsId,
    required this.patientId,
    required this.recommendationId,
    required this.phone,
    required this.message,
    required this.sentBy,
    required this.provider,
    required this.status,
    this.failureReason,
    required this.sentAt,
  });

  factory SmsLog.fromJson(Map<String, dynamic> json) => SmsLog(
        smsId: json['sms_id'] as String,
        patientId: json['patient_id'] as String,
        recommendationId: json['recommendation_id'] as String,
        phone: json['phone'] as String,
        message: json['message'] as String,
        sentBy: json['sent_by'] as String,
        provider: json['provider'] as String,
        status: SmsStatusX.fromWire(json['status'] as String),
        failureReason: json['failure_reason'] as String?,
        sentAt: DateTime.parse(json['sent_at'] as String),
      );
}
