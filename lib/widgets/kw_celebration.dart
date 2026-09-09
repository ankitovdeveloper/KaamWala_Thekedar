import 'package:flutter/material.dart';

import '../core/animations/celebration.dart';
import '../core/animations/entrance.dart';
import '../core/audio/app_sounds.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/session.dart';
import 'kw_button.dart';

/// The app's one success popup: a green tick that draws itself, confetti over
/// the whole screen, and a chime behind it.
///
/// Replaces the snackbar that used to mark these moments. A snackbar is right
/// for "saved" and "copied"; it is far too quiet for the four or five moments
/// this app actually turns on — a worker saying yes, the kaam starting, the
/// kaam finishing, and the money being settled. Those are the payoffs the whole
/// booking exists for, and they should feel like it.
///
/// Everything here is decoration over a result that has already happened, so
/// nothing in it can fail loudly: the sound is best-effort, and "reduce motion"
/// drops the paper and the drawing and keeps the words.
class KwCelebration extends StatelessWidget {
  const KwCelebration({
    super.key,
    required this.title,
    this.message,
    this.detail,
    this.detailIcon,
    this.primaryLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// One line, past tense — the thing that just became true.
  final String title;

  /// The consequence: what happens next, or what it means.
  final String? message;

  /// The fact worth keeping in view — an amount, a name, a time. Rendered as a
  /// green chip under the message.
  final String? detail;

  final IconData? detailIcon;

  /// Defaults to a plain "Theek hai" dismiss.
  final String? primaryLabel;

  /// Optional way onward — "Track karein", "Review dein".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Shows the popup and completes when it closes.
  ///
  /// [onSecondary] runs *after* the popup is gone, so a caller can navigate
  /// without fighting the dialog's own pop.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    String? detail,
    IconData? detailIcon,
    String? primaryLabel,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool sound = true,
  }) {
    if (sound) AppSounds.success();

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      // Darker than a stock dialog scrim: the confetti is drawn over it, and
      // yellow paper on a pale veil is barely there.
      barrierColor: const Color(0x8C000000),
      transitionDuration: Motion.normal,
      pageBuilder: (context, _, _) => KwCelebration(
        title: title,
        message: message,
        detail: detail,
        detailIcon: detailIcon,
        primaryLabel: primaryLabel,
        secondaryLabel: secondaryLabel,
        onSecondary: onSecondary,
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Motion.spring,
          reverseCurve: Motion.exit,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.x5l,
              vertical: Gap.x7l,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Material(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(Radii.pill),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A green wash behind the tick, fading into the white body,
                    // so the badge sits in the card rather than on it.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(
                        top: Gap.x6l,
                        bottom: Gap.x4l,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.successBg, AppColors.white],
                        ),
                      ),
                      child: const Center(child: SuccessBurst(size: 104)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.x5l,
                        0,
                        Gap.x5l,
                        Gap.x5l,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: Stagger.wrap(
                          // Behind the tick, so the words arrive as it lands.
                          base: const Duration(milliseconds: 260),
                          step: const Duration(milliseconds: 60),
                          offset: 12,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: AppType.h3.copyWith(fontSize: 19),
                            ),
                            if (message case final text?) ...[
                              Gap.vMd,
                              Text(
                                text,
                                textAlign: TextAlign.center,
                                style: AppType.bodyMuted,
                              ),
                            ],
                            if (detail case final text?) ...[
                              Gap.v16,
                              _DetailChip(text: text, icon: detailIcon),
                            ],
                            Gap.v24,
                            KwButton(
                              label: primaryLabel ?? s.celebrateOk,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            if (secondaryLabel case final label?) ...[
                              Gap.vMd,
                              KwButton(
                                label: label,
                                variant: KwButtonVariant.ghost,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onSecondary?.call();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Over the card, not under it: paper that vanishes behind the thing
        // being celebrated reads as a rendering bug.
        const Positioned.fill(
          child: Confetti(origin: Alignment(0, -0.28)),
        ),
      ],
    );
  }
}

/// The one fact worth keeping in view — an amount, a name, a time.
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x3l,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: Radii.rPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final glyph?) ...[
              Icon(glyph, size: 15, color: AppColors.successDark),
              Gap.hSm,
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppType.bodyStrong.copyWith(
                  fontSize: 13,
                  color: AppColors.successDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
