import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/staff.dart';
import '../services/api_service.dart';

/// Full staff directory (admin only) — mutated in place on
/// activate/deactivate so the list updates without a full re-fetch.
class StaffListNotifier extends Notifier<AsyncValue<List<Staff>>> {
  @override
  AsyncValue<List<Staff>> build() {
    Future.microtask(refresh);
    return const AsyncValue.loading();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final staff = await apiService.fetchStaff();
      state = AsyncValue.data(staff);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> setActive(String staffId, bool active) async {
    try {
      final updated = active
          ? await apiService.activateStaff(staffId)
          : await apiService.deactivateStaff(staffId);
      final current = state.value ?? const <Staff>[];
      state = AsyncValue.data([
        for (final s in current) s.staffId == staffId ? updated : s,
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final staffListProvider =
    NotifierProvider<StaffListNotifier, AsyncValue<List<Staff>>>(
        StaffListNotifier.new);

/// Active doctors only — feeds the receptionist's "assign doctor" picker.
final activeDoctorsProvider = FutureProvider<List<Staff>>((ref) {
  return apiService.fetchDoctors();
});
