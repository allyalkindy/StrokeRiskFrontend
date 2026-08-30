import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/staff.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin/add_staff.dart';
import '../../screens/admin/admin_dashboard.dart';
import '../../screens/admin/staff_list.dart';
import '../../screens/assessment/assessment_form.dart';
import '../../screens/assessment/lab_request_form.dart';
import '../../screens/assessment/prediction_result.dart';
import '../../screens/assessment/visit_detail.dart';
import '../../screens/auth/login.dart';
import '../../screens/auth/splash.dart';
import '../../screens/dashboard/dashboard_shell.dart';
import '../../screens/dashboard/doctor_dashboard.dart';
import '../../screens/dashboard/doctor_queue.dart';
import '../../screens/lab/lab_queue.dart';
import '../../screens/lab/lab_request_detail.dart';
import '../../screens/patients/add_patient.dart';
import '../../screens/patients/patient_profile.dart';
import '../../screens/patients/search_patient.dart';
import '../../screens/reception/assign_doctor.dart';
import '../../screens/recommendation/recommendation_review.dart';
import '../../screens/reports/analytics.dart';

/// Routes reachable without an authenticated session.
const _publicPaths = ['/splash', '/login'];

bool _isPublic(String location) =>
    _publicPaths.any((p) => location == p || location.startsWith('$p/'));

/// True if [location] falls under any of [prefixes] (exact match or a
/// nested sub-route).
bool _underAny(String location, List<String> prefixes) => prefixes
    .any((p) => location == p || location.startsWith('$p/'));

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: authRefreshNotifier,
  redirect: (context, state) {
    // `listen: false` — re-evaluation is driven by `refreshListenable`
    // (authRefreshNotifier), not by an InheritedWidget dependency, and
    // this callback may run outside of a normal widget build phase.
    final auth =
        ProviderScope.containerOf(context, listen: false).read(authProvider);
    final loc = state.matchedLocation;

    if (!auth.isLoggedIn) {
      return _isPublic(loc) ? null : '/login';
    }

    final role = auth.currentUser!.role;

    // Signed-in users don't linger on splash/login — send them home.
    if (loc == '/splash' || loc == '/login') return role.homePath;

    // Admin oversees the whole system — no section gating.
    if (role == StaffRole.admin) return null;

    if (_underAny(loc, ['/patients/add']) &&
        role != StaffRole.receptionist) {
      return role.homePath;
    }
    if (_underAny(
            loc, ['/dashboard', '/queue', '/assessment', '/recommendations']) &&
        role != StaffRole.doctor) {
      return role.homePath;
    }
    // Visit details are Doctor territory (record vitals, request labs,
    // continue to assessment) but Receptionist can also open them
    // read-only from a patient's "Previous visits" list — they created
    // those check-ins and reasonably need to see what happened next.
    if (_underAny(loc, ['/visits']) &&
        role != StaffRole.doctor &&
        role != StaffRole.receptionist) {
      return role.homePath;
    }
    if (_underAny(loc, ['/reception']) && role != StaffRole.receptionist) {
      return role.homePath;
    }
    if (_underAny(loc, ['/lab']) && role != StaffRole.labScientist) {
      return role.homePath;
    }
    if (_underAny(loc, ['/admin']) && role != StaffRole.admin) {
      return role.homePath;
    }

    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) => DashboardShell(child: child),
      routes: [
        // ── Doctor ──────────────────────────────────────────────
        GoRoute(
            path: '/dashboard', builder: (c, s) => const DoctorDashboard()),
        GoRoute(path: '/queue', builder: (c, s) => const DoctorQueueScreen()),
        GoRoute(
          path: '/visits/:visitId',
          builder: (c, s) =>
              VisitDetailScreen(visitId: s.pathParameters['visitId']!),
          routes: [
            GoRoute(
              path: 'lab-request',
              builder: (c, s) => LabRequestFormScreen(
                  visitId: s.pathParameters['visitId']!),
            ),
          ],
        ),
        GoRoute(
          path: '/assessment',
          builder: (c, s) =>
              AssessmentFormScreen(visitId: s.uri.queryParameters['visit']),
          routes: [
            GoRoute(
                path: 'result',
                builder: (c, s) => const PredictionResultScreen()),
          ],
        ),
        GoRoute(
          path: '/recommendations/:patientId',
          builder: (c, s) => RecommendationReviewScreen(
              patientId: s.pathParameters['patientId']!),
        ),

        // ── Shared: patients ────────────────────────────────────
        GoRoute(
          path: '/patients',
          builder: (c, s) => const SearchPatientScreen(),
          routes: [
            GoRoute(
                path: 'add', builder: (c, s) => const AddPatientScreen()),
            GoRoute(
              path: ':id',
              builder: (c, s) =>
                  PatientProfileScreen(patientId: s.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
          path: '/analytics',
          builder: (c, s) =>
              AnalyticsScreen(patientId: s.uri.queryParameters['patient']),
        ),

        // ── Admin ───────────────────────────────────────────────
        GoRoute(path: '/admin', builder: (c, s) => const AdminDashboard()),
        GoRoute(
          path: '/admin/staff',
          builder: (c, s) => const StaffListScreen(),
          routes: [
            GoRoute(path: 'add', builder: (c, s) => const AddStaffScreen()),
          ],
        ),

        // ── Receptionist ────────────────────────────────────────
        GoRoute(
          path: '/reception/assign',
          builder: (c, s) => const AssignDoctorScreen(),
          routes: [
            GoRoute(
              path: ':visitId',
              builder: (c, s) => AssignDoctorScreen(
                  visitId: s.pathParameters['visitId']),
            ),
          ],
        ),

        // ── Lab scientist ───────────────────────────────────────
        GoRoute(
          path: '/lab',
          builder: (c, s) => const LabQueueScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (c, s) => LabRequestDetailScreen(
                  labRequestId: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
  ],
);
