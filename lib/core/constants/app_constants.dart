import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  AppConstants._();

  static const String appName = 'StrokeGuard';
  static const String appTagline =
      'Intelligent Stroke Risk Assessment & Lifestyle Recommendations';

  /// FastAPI backend base URL.
  ///
  /// - Override at build time: --dart-define=API_BASE_URL=http://server:8000
  /// - Android emulator reaches the host machine via 10.0.2.2
  /// - Web/desktop use localhost
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  // API endpoints (mirror the backend plan)
  static const String epAuthLogin = '/auth/login';
  static const String epAuthRegister = '/auth/register';
  static const String epPatients = '/patients';
  static const String epPredictionAnalyze = '/prediction/analyze';
  static const String epRecommendations = '/recommendations';
  static const String epReports = '/reports';

  // Layout
  static const double pagePadding = 24;
  static const double cardGap = 16;
  static const double maxFormWidth = 440;
  static const double wideBreakpoint = 900;
}
