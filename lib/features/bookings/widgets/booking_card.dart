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
    required this.onCancel,
    required this.onReview,
    required this.onTrack,
  });

  final Booking booking;
  final VoidCallback onCall;
  final VoidCallback onDetails;
  final VoidCallback onCancel;
  final VoidCallback onReview;
  final VoidCallback onTrack;

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
        KwChipButton(label: s.bookAgain, onPressed: onDetails),
      ],
    };
  }

  Widget _info(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppType.caption,
            maxLines: 1,
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
