import 'package:dio/dio.dart';

/// Turns a caught error into text a Doctor/Receptionist/Lab Scientist can
/// actually act on, instead of a blanket "check the backend connection"
/// that's wrong for anything other than a real connectivity failure.
///
/// Prefers the backend's own message: FastAPI's `HTTPException(detail=...)`
/// puts a string at `detail`; a Pydantic validation error (422) puts a
/// list of `{loc, msg, type}` there instead — both are handled.
String friendlyError(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          final loc = first['loc'];
          final field = loc is List && loc.isNotEmpty ? loc.last : null;
          return field != null ? '$field: ${first['msg']}' : first['msg'] as String;
        }
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check that the backend is running '
          'and the app points to the right address.';
    }
  }
  return fallback;
}
