import 'package:flutter/material.dart';

import '../../core/animations/effects.dart';
import '../../core/animations/entrance.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/session.dart';
import '../../widgets/kw_scaffold.dart';

/// First route of the app, and the only thing that decides where a cold start
/// lands.
///
/// [Session.restore] reads the persisted Sanctum token off `shared_preferences`
/// asynchronously, so the very first frame cannot know whether there is a
/// signed-in user yet. This screen holds that frame — brand mark on yellow, the
/// same one the login screen opens with, so the handover doesn't read as a
/// flash — and replaces itself with Search or Login the moment
/// [Session.isRestored] flips.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// `read`, not `context.session` — subscribing from initState throws, and the
  /// listener below is what this screen actually reacts to.
  late final Session _session = SessionScope.read(context);

  /// Guards against handing over twice: the listener and the post-frame check
  /// can both fire for the same restore.
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handOver);
    // Restore can finish before this screen is built — a mock session has
    // nothing to read and completes synchronously — so don't wait on a
    // notification that has already been sent.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handOver());
  }

  @override
  void dispose() {
    _session.removeListener(_handOver);
    super.dispose();
  }

  void _handOver() {
    if (_handedOver || !mounted || !_session.isRestored) return;
    _handedOver = true;

    // A restored token goes straight to the shell; anything else asks for the
    // phone number again. `pushReplacement` so back never returns here.
    Navigator.of(context).pushReplacementNamed(
      _session.isAuthenticated ? Routes.home : Routes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return KwScaffold(
      backgroundColor: AppColors.yellow,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeSlideIn(
              from: SlideFrom.none,
              beginScale: 0.6,
              duration: Motion.lazy,
              curve: Motion.settle,
              child: Floating(
                amplitude: 4,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.floatingShadow,
                  ),
                  child: const Icon(
                    Icons.handyman_rounded,
                    size: 40,
                    color: AppColors.black,
                  ),
                ),
              ),
            ),
            Gap.vXxl,
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              offset: 10,
              child: Text(s.appName, style: AppType.h1),
            ),
            Gap.vSm,
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              offset: 10,
              child: Text(
                s.tagline,
                style: AppType.caption.copyWith(
                  color: AppColors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
            Gap.v32,
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
