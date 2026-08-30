import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui_kit.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Restores a cached session (if any) while the brand animation plays,
  /// then hands off to /login — the router's `redirect` takes it from
  /// there, bouncing an already-authenticated staff member straight to
  /// their role-specific home.
  Future<void> _bootstrap() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 2200));
    final restore = ref.read(authProvider.notifier).restoreSession();
    await Future.wait([minDelay, restore]);
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
          child: Stack(
            children: [
              // Soft decorative circles.
              Positioned(
                top: -80,
                right: -60,
                child: _circle(220, Colors.white.withValues(alpha: .05)),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: _circle(280, Colors.white.withValues(alpha: .04)),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .25),
                          ),
                        ),
                        child: const Icon(Icons.monitor_heart_rounded,
                            color: Colors.white, size: 56),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Text(
                        AppConstants.appName,
                        style: text.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          AppConstants.appTagline,
                          textAlign: TextAlign.center,
                          style: text.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: .75),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 650),
                      child: SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          borderRadius:
                              const BorderRadius.all(Radius.circular(4)),
                          color: Colors.white,
                          backgroundColor:
                              Colors.white.withValues(alpha: .2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer note.
              Positioned(
                left: 0,
                right: 0,
                bottom: 32,
                child: Text(
                  'Intelligent care, powered by AI',
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .5),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
