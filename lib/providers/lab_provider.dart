import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lab_request.dart';
import '../services/api_service.dart';

/// Pending + in-progress lab requests (the lab scientist's queue), or a
/// specific [status] filter.
final labQueueProvider =
    FutureProvider.family<List<LabRequest>, String?>((ref, status) {
  return apiService.fetchLabQueue(status: status);
});

/// One-shot lab request detail fetch (no polling) — used by the lab
/// scientist's own submission form, which doesn't need to watch itself
/// for updates.
final labRequestDetailProvider =
    FutureProvider.family<LabRequestDetail, String>((ref, labRequestId) {
  return apiService.fetchLabRequestDetail(labRequestId);
});

/// Polls a single lab request roughly every 5 seconds while it's pending
/// or in progress, so a doctor waiting on results sees the moment the lab
/// scientist submits them — stops once the request is
/// `completed`/`cancelled`, or when nothing is watching this provider
/// anymore (autoDispose).
class LabRequestPollingNotifier
    extends Notifier<AsyncValue<LabRequestDetail>> {
  LabRequestPollingNotifier(this.labRequestId);

  final String labRequestId;
  Timer? _timer;

  @override
  AsyncValue<LabRequestDetail> build() {
    ref.onDispose(() => _timer?.cancel());
    _fetch();
    return const AsyncValue.loading();
  }

  Future<void> _fetch() async {
    try {
      final detail = await apiService.fetchLabRequestDetail(labRequestId);
      state = AsyncValue.data(detail);
      final status = detail.request.status;
      if (status == LabRequestStatus.completed ||
          status == LabRequestStatus.cancelled) {
        return; // Reached a terminal state — stop polling.
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _fetch);
  }

  /// Manual refresh (e.g. pull-to-refresh) without waiting for the timer.
  Future<void> refreshNow() => _fetch();
}

// `autoDispose` so the timer (and the background polling it drives) is
// torn down as soon as nothing is watching a given lab request anymore —
// e.g. the doctor navigates away from the visit detail page.
final labRequestPollingProvider = NotifierProvider.autoDispose.family<
    LabRequestPollingNotifier, AsyncValue<LabRequestDetail>, String>(
  LabRequestPollingNotifier.new,
);
