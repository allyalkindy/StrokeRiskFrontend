import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/error_message.dart';
import '../models/staff.dart';
import '../services/auth_service.dart';

/// Plain [ChangeNotifier] singleton the auth provider pings after every
/// login/logout/session-restore — go_router's `redirect` listens to this
/// via `refreshListenable` so it re-evaluates immediately, without polling.
/// It has to live outside Riverpod because `appRouter` is a top-level
/// object built before any [ProviderContainer] exists.
class AuthRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

final authRefreshNotifier = AuthRefreshNotifier();

class AuthState {
  final Staff? currentUser;
  final bool loading;
  final String? error;

  const AuthState({this.currentUser, this.loading = false, this.error});

  bool get isLoggedIn => currentUser != null;

  AuthState copyWith({Staff? currentUser, bool? loading, String? error}) =>
      AuthState(
        currentUser: currentUser ?? this.currentUser,
        loading: loading ?? this.loading,
        error: error,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  final _service = const AuthService();

  @override
  AuthState build() => const AuthState();

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true);
    try {
      final staff = await _service.login(email: email, password: password);
      state = AuthState(currentUser: staff);
      authRefreshNotifier.ping();
      return true;
    } catch (e) {
      state = AuthState(
          error: friendlyError(e, 'Login failed. Please try again.'));
      return false;
    }
  }

  /// Restores a cached session on app start (called from the splash
  /// screen) — instant, and doesn't require the backend to be reachable.
  Future<void> restoreSession() async {
    if (!await _service.hasSession()) {
      authRefreshNotifier.ping();
      return;
    }
    final cached = await _service.cachedStaff();
    state = AuthState(currentUser: cached);
    authRefreshNotifier.ping();
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
    authRefreshNotifier.ping();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
