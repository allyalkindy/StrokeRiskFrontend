import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommendation.dart';
import '../models/sms_log.dart';
import '../services/api_service.dart';

/// Recommendation history for a patient, newest first (unchanged path,
/// richer shape — approval status, timestamps).
final recommendationsProvider =
    FutureProvider.family<List<Recommendation>, String>((ref, patientId) {
  return apiService.fetchRecommendations(patientId);
});

/// Doctor review state for the recommendation approval workflow: which AI
/// suggestions are accepted, the extra advice text, and the in-flight
/// approve/reject/SMS actions.
class RecommendationReviewState {
  final Recommendation? recommendation;
  final Set<int> accepted; // indices of accepted AI suggestions
  final String doctorAdvice;
  final bool submitting;
  final bool sendingSms;
  final SmsLog? lastSms;
  final Object? lastError;

  const RecommendationReviewState({
    this.recommendation,
    this.accepted = const {},
    this.doctorAdvice = '',
    this.submitting = false,
    this.sendingSms = false,
    this.lastSms,
    this.lastError,
  });

  bool get isApproved =>
      recommendation?.approvalStatus == ApprovalStatus.approved;
  bool get isRejected =>
      recommendation?.approvalStatus == ApprovalStatus.rejected;

  RecommendationReviewState copyWith({
    Recommendation? recommendation,
    Set<int>? accepted,
    String? doctorAdvice,
    bool? submitting,
    bool? sendingSms,
    SmsLog? lastSms,
    Object? lastError,
  }) =>
      RecommendationReviewState(
        recommendation: recommendation ?? this.recommendation,
        accepted: accepted ?? this.accepted,
        doctorAdvice: doctorAdvice ?? this.doctorAdvice,
        submitting: submitting ?? this.submitting,
        sendingSms: sendingSms ?? this.sendingSms,
        lastSms: lastSms ?? this.lastSms,
        lastError: lastError,
      );
}

class RecommendationReviewNotifier extends Notifier<RecommendationReviewState> {
  @override
  RecommendationReviewState build() => const RecommendationReviewState();

  void loadFrom(Recommendation recommendation) {
    state = RecommendationReviewState(
      recommendation: recommendation,
      accepted: {
        for (var i = 0; i < recommendation.aiAdvice.length; i++) i,
      },
      doctorAdvice: recommendation.doctorAdvice ?? '',
    );
  }

  void toggle(int index) {
    final next = Set<int>.from(state.accepted);
    next.contains(index) ? next.remove(index) : next.add(index);
    state = state.copyWith(accepted: next);
  }

  void setDoctorAdvice(String text) =>
      state = state.copyWith(doctorAdvice: text);

  /// PUT /recommendations/approve.
  Future<bool> approve() async {
    final rec = state.recommendation;
    if (rec == null) return false;
    state = state.copyWith(submitting: true);
    try {
      final allAccepted = state.accepted.length == rec.aiAdvice.length;
      final updated = await apiService.approveRecommendation(
        recommendationId: rec.recommendationId,
        acceptedIndices: allAccepted ? null : (state.accepted.toList()..sort()),
        doctorAdvice:
            state.doctorAdvice.trim().isEmpty ? null : state.doctorAdvice.trim(),
      );
      state = state.copyWith(recommendation: updated, submitting: false);
      ref.invalidate(recommendationsProvider(updated.patientId));
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, lastError: e);
      return false;
    }
  }

  /// PUT /recommendations/reject.
  Future<bool> reject() async {
    final rec = state.recommendation;
    if (rec == null) return false;
    state = state.copyWith(submitting: true);
    try {
      final updated = await apiService.rejectRecommendation(
        recommendationId: rec.recommendationId,
        doctorAdvice:
            state.doctorAdvice.trim().isEmpty ? null : state.doctorAdvice.trim(),
      );
      state = state.copyWith(recommendation: updated, submitting: false);
      ref.invalidate(recommendationsProvider(updated.patientId));
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, lastError: e);
      return false;
    }
  }

  /// POST /recommendations/{id}/send-sms — a separate explicit action from
  /// [approve], only meaningful once approved. Re-checks the delivery
  /// status once, a moment later, since the (simulated) SMS gateway may
  /// still be "pending" in the immediate response.
  Future<bool> sendSms() async {
    final rec = state.recommendation;
    if (rec == null || rec.approvalStatus != ApprovalStatus.approved) {
      return false;
    }
    state = state.copyWith(sendingSms: true);
    try {
      final log = await apiService.sendRecommendationSms(rec.recommendationId);
      state = state.copyWith(lastSms: log, sendingSms: false);
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          final history = await apiService.fetchSmsLog(rec.recommendationId);
          if (history.isNotEmpty) {
            state = state.copyWith(lastSms: history.first);
          }
        } catch (_) {
          // Keep the immediate send result if the follow-up check fails.
        }
      });
      return true;
    } catch (e) {
      state = state.copyWith(sendingSms: false, lastError: e);
      return false;
    }
  }
}

final recommendationReviewProvider = NotifierProvider<
    RecommendationReviewNotifier, RecommendationReviewState>(
  RecommendationReviewNotifier.new,
);
