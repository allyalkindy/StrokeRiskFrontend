import 'dart:convert';

import '../core/constants/app_constants.dart';
import '../core/network/api_client.dart';
import '../models/staff.dart';

/// Staff authentication against the FastAPI backend.
///
/// There is no public self-registration flow — only an Admin can create
/// new staff accounts, via [createStaff].
class AuthService {
  const AuthService();

  Future<Staff> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.dio.post(
      AppConstants.epAuthLogin,
      data: {'email': email, 'password': password},
    );
    await ApiClient.storage.write(
      key: ApiClient.tokenKey,
      value: res.data['access_token'] as String,
    );
    final staff = Staff.fromJson(res.data['staff'] as Map<String, dynamic>);
    await ApiClient.storage.write(
      key: ApiClient.staffKey,
      value: jsonEncode(staff.toJson()),
    );
    return staff;
  }

  /// Admin-only: create a new staff account of any role.
  Future<Staff> createStaff({
    required String staffId,
    required String name,
    required String email,
    required StaffRole role,
    String? hospital,
    String? phone,
    required String password,
  }) async {
    final res = await ApiClient.dio.post(
      AppConstants.epAuthRegister,
      data: {
        'staff_id': staffId,
        'name': name,
        'email': email,
        'role': role.wireValue,
        'hospital': hospital,
        'phone': phone,
        'password': password,
      },
    );
    return Staff.fromJson(res.data as Map<String, dynamic>);
  }

  Future<bool> hasSession() async {
    final token = await ApiClient.storage.read(key: ApiClient.tokenKey);
    return token != null;
  }

  /// The signed-in staff member cached from the last login, if any — lets
  /// the splash screen restore a session instantly without waiting on the
  /// network.
  Future<Staff?> cachedStaff() async {
    final raw = await ApiClient.storage.read(key: ApiClient.staffKey);
    if (raw == null) return null;
    try {
      return Staff.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await ApiClient.storage.delete(key: ApiClient.tokenKey);
    await ApiClient.storage.delete(key: ApiClient.staffKey);
  }
}
