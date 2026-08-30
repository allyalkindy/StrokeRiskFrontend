import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prediction.dart';
import '../services/api_service.dart';
import 'visit_provider.dart';

class PredictionState {
  final Prediction? current;
  final bool loading;

  const PredictionState({this.current, this.loading = false});
}

class PredictionNotifier extends Notifier<PredictionState> {
  @override
  PredictionState build() => const PredictionState();

  Future<Prediction> analyze(AssessmentInput input) async {
    state = const PredictionState(loading: true);
    try {
      final prediction = await apiService.analyzeStrokeRisk(input);
      state = PredictionState(current: prediction);
      // The visit just flipped to "completed" server-side — drop it from
      // any cached doctor queue and refresh its detail view.
      ref.invalidate(doctorQueueProvider);
      ref.invalidate(visitDetailProvider(input.visitId));
      return prediction;
    } catch (_) {
      state = const PredictionState();
      rethrow;
    }
  }
}

final predictionProvider =
    NotifierProvider<PredictionNotifier, PredictionState>(
        PredictionNotifier.new);

/// Assessment history per patient, fetched from the backend
/// (drives profile + analytics charts). Refreshes after each new
/// assessment because it watches [predictionProvider].
final predictionHistoryProvider =
    FutureProvider.family<List<Prediction>, String>((ref, patientId) {
  ref.watch(predictionProvider);
  return apiService.fetchHistory(patientId);
});

/// Every assessment run on a visit assigned to [doctorId] — the Doctor's
/// Reports tab landing list (only their own assessed patients). Refreshes
/// after each new assessment because it watches [predictionProvider].
final predictionsByDoctorProvider =
    FutureProvider.family<List<Prediction>, String>((ref, doctorId) {
  ref.watch(predictionProvider);
  return apiService.fetchPredictionsByDoctor(doctorId);
});

