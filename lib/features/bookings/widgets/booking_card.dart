import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onCall,
    required this.onDetails,
    required this.onBookAgain,
    required this.onCancel,
    required this.onReview,
    required this.onTrack,
    required this.onComplete,
    required this.onPaymentDone,
  });

  final Booking booking;
  final VoidCallback onCall;

  /// Opens this booking's own record — what happened on it, step by step.
  ///
  /// Used to open the worker's profile, which answered a different question
  /// than the one a tap on a booking is asking.
  final VoidCallback onDetails;

  /// Opens the worker's profile to book them again — the one place on this card
  /// where the *worker* really is what the tap is about.
  final VoidCallback onBookAgain;

  final VoidCallback onCancel;
  final VoidCallback onReview;
  final VoidCallback onTrack;

  /// "Kaam poora hua" and then "Payment done" — the two halves of wrapping a
  /// job up. Two taps because they are two facts, usually hours apart.
  final VoidCallback onComplete;
  final VoidCallback onPaymentDone;

  (String, KwStatusTone) _status(AppStrings s) => switch (booking.status) {
    BookingStatus.accepted => (s.statusConfirmed, KwStatusTone.confirmed),
    BookingStatus.pending => (s.statusPending, KwStatusTone.pending),
    BookingStatus.completed => (s.statusCompleted, KwStatusTone.done),
    BookingStatus.cancelled => (s.statusCancelled, KwStatusTone.cancelled),
    BookingStatus.declined => (s.statusDeclined, KwStatusTone.cancelled),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final (statusLabel, tone) = _status(s);
    final dimmed =
        booking.isDone ||
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.declined;

    return AnimatedOpacity(
      duration: Motion.normal,
      opacity: dimmed ? 0.72 : 1,
      child: KwCard(
        margin: const EdgeInsets.only(bottom: Gap.xl),
        padding: const EdgeInsets.fromLTRB(Gap.x3l, Gap.xxl, Gap.x3l, Gap.xxl),
        onTap: onDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KwAvatar(initials: booking.labour.initials, size: 38),
                Gap.hLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        booking.labour.name,
                        style: AppType.bodyStrong.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.handyman_outlined,
                            size: 12,
                            color: AppColors.muted,
                          ),
                          Gap.hXs,
                          Flexible(
                            child: Text(
                              booking.skillName ?? s.workGeneric,
                              style: AppType.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Gap.hMd,
                KwStatusBadge(label: statusLabel, tone: tone),
              ],
            ),
            Gap.vLg,
            // Live progress strip — only meaningful while work is underway.
            if (booking.status == BookingStatus.accepted) ...[
              _StageTracker(stage: booking.jobStage),
              Gap.vXl,
            ],
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _info(Icons.calendar_today_outlined, booking.whenLabelIn(s)),
                  if (booking.address != null) ...[
                    Gap.vXs,
                    _info(Icons.location_on_outlined, booking.address!),
                  ],
                  if (!booking.isDone) ...[
                    Gap.vXs,
                    _info(Icons.schedule_rounded, booking.dayType.labelIn(s)),
                  ],
                  // On a finished job these two lines are the whole story: has
                  // the money moved, and has the worker agreed it is settled.
                  if (booking.isDone) ...[
                    Gap.vXs,
                    _info(
                      booking.paymentDone
                          ? Icons.check_circle_outline_rounded
                          : Icons.payments_outlined,
                      booking.paymentDone ? s.paymentDone : s.paymentPending,
                    ),
                    if (booking.completionDisputed) ...[
                      Gap.vXs,
                      // The one line on this card that contradicts the rest of
                      // it, so it gets the colour: status and payment both still
                      // read as finished, because they record what was declared.
                      _info(
                        Icons.report_gmailerrorred_rounded,
                        booking.completionRemark?.isNotEmpty == true
                            ? '${s.labourDisputed(booking.labour.name)}: '
                                  '${booking.completionRemark}'
                            : s.labourDisputed(booking.labour.name),
                        tone: AppColors.danger,
                      ),
                    ] else if (booking.awaitingLabourConfirm) ...[
                      Gap.vXs,
                      _info(
                        Icons.hourglass_empty_rounded,
                        s.awaitingLabourConfirm(booking.labour.name),
                      ),
                    ] else if (booking.completionSettled) ...[
                      Gap.vXs,
                      _info(
                        Icons.verified_outlined,
                        s.labourConfirmed(booking.labour.name),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Gap.vXl,
            // Wrap rather than Row: on a narrow phone (or at large font
            // scale) the action buttons drop to their own line instead of
            // running off the card.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Gap.md,
              runSpacing: Gap.lg,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.xl,
                    vertical: Gap.xs,
                  ),
                  decoration: BoxDecoration(
                    color: dimmed ? AppColors.doneBg : AppColors.yellow,
                    borderRadius: Radii.rPill,
                  ),
                  child: Text(
                    '₹${booking.price}',
                    style: AppType.price.copyWith(
                      fontSize: 13,
                      color: dimmed ? AppColors.muted : AppColors.black,
                    ),
                  ),
                ),
                Wrap(
                  spacing: Gap.md,
                  runSpacing: Gap.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _actions(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Spacing is supplied by the enclosing Wrap, so no gaps in here.
  List<Widget> _actions(AppStrings s) {
    return switch (booking.status) {
      BookingStatus.accepted => [
        // Only offered while there is something to watch — a finished job has
        // no position left to follow.
        if (booking.isTrackable)
          KwChipButton(
            label: s.liveTrack,
            icon: Icons.near_me_rounded,
            filled: true,
            onPressed: onTrack,
          ),
        if (booking.canComplete)
          KwChipButton(
            label: s.markWorkDone,
            icon: Icons.task_alt_rounded,
            onPressed: onComplete,
          ),
        KwChipButton(
          label: s.call,
          icon: Icons.phone_outlined,
          onPressed: onCall,
        ),
        KwChipButton(label: s.details, onPressed: onDetails),
      ],
      BookingStatus.pending => [
        KwChipButton(label: s.cancel, danger: true, onPressed: onCancel),
        KwChipButton(label: s.details, onPressed: onDetails),
      ],
      BookingStatus.completed => [
        // The money is the loudest thing left on a finished job.
        if (booking.canMarkPayment)
          KwChipButton(
            label: s.markPaymentDone,
            icon: Icons.payments_outlined,
            filled: true,
            onPressed: onPaymentDone,
          ),
        if (booking.hasReview)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              Gap.hXs,
              Text(s.reviewDone, style: AppType.micro),
            ],
          )
        else
          KwChipButton(
            label: s.giveReview,
            icon: Icons.star_outline_rounded,
            filled: true,
            onPressed: onReview,
          ),
      ],
      BookingStatus.cancelled || BookingStatus.declined => [
        KwChipButton(label: s.details, onPressed: onDetails),
        KwChipButton(label: s.bookAgain, filled: true, onPressed: onBookAgain),
      ],
    };
  }

  /// [tone] overrides the muted default — used only where the line contradicts
  /// the rest of the card, which is a thing worth colouring.
  Widget _info(IconData icon, String text, {Color? tone}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: tone ?? AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: tone == null
                ? AppType.caption
                : AppType.caption.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w600,
                  ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Four-step progress line for a confirmed booking. The current step's dot
/// pulses so it's obvious where the job is right now.
class _StageTracker extends StatelessWidget {
  const _StageTracker({required this.stage});

  final JobStage stage;

  @override
  Widget build(BuildContext context) {
    const stages = JobStage.values;
    final currentIndex = stages.indexOf(stage);

    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < stages.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: i <= currentIndex ? 1 : 0),
                      duration: Motion.lazy,
                      curve: Motion.enter,
                      builder: (context, t, _) => Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: LinearGradient(
                            colors: const [
                              AppColors.yellowDark,
                              AppColors.border,
                            ],
                            stops: [t, t],
                          ),
                        ),
                      ),
                    ),
                  ),
                _Dot(
                  filled: i <= currentIndex,
                  current: i == currentIndex,
                  delay: Duration(milliseconds: 120 * i),
                ),
              ],
            ],
          ),
          Gap.vSm,
          Text(
            stage.labelIn(context.s),
            style: AppType.micro.copyWith(
              color: AppColors.successDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.filled,
    required this.current,
    required this.delay,
  });

  final bool filled;
  final bool current;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.normal,
      curve: Motion.settle,
      builder: (context, t, _) => Transform.scale(
        scale: t,
        child: AnimatedContainer(
          duration: Motion.normal,
          width: current ? 11 : 8,
          height: current ? 11 : 8,
          decoration: BoxDecoration(
            color: filled ? AppColors.yellowDark : AppColors.border,
            shape: BoxShape.circle,
            border: current
                ? Border.all(color: AppColors.black, width: 1.5)
                : null,
          ),
        ),
      ),
    );
  }
}
