import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroke_guard/main.dart';

void main() {
  testWidgets('App boots to the splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StrokeGuardApp()));
    expect(find.text('StrokeGuard'), findsOneWidget);

    // Splash navigates to the login screen after its 2s timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Doctor'), findsOneWidget);
  });
}
