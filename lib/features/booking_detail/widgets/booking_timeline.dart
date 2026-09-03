import 'package:flutter/material.dart';

import '../../../core/animations/effects.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';

/// "Kya kya hua" — a booking's whole history as a vertical list of steps.
///
/// Vertical rather than the four-dot strip on the booking card, because this is
/// the screen where the *times* matter: a job that ended badly is argued about
/// with "he set off at 10, reached at 11:40", and a row of dots has nowhere to
/// put that. Each step gets a line of its own, its own timestamp, and the note
/// the server attached to it.
///
/// The list is not a fixed ladder. The server drops the steps a stopped job
/// never reached rather than leaving them looking due, so a cancelled booking
/// simply ends — see `App\Support\BookingStory`.
class BookingTimeline extends StatelessWidget {
  const BookingTimeline({super.key, required this.steps});

  final List<BookingStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text(context.s.nothingHappenedYet, style: AppType.bodyMuted);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            step: steps[i],
            // The line above a step is filled when the step *before* it
            // happened, so the trail stops exactly where the booking did.
            trailAbove: i == 0 ? null : steps[i - 1].isReached,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.trailAbove,
    required this.isLast,
  });

  final BookingStep step;

  /// Whether the connector coming down into this step is filled. Null on the
  /// first step, which has nothing above it.
  final bool? trailAbove;

  final bool isLast;

  /// One icon per step, so the list is scannable without reading it.
  IconData get _icon => switch (step.code) {
    BookingStepCode.requested => Icons.send_rounded,
    BookingStepCode.accepted => Icons.how_to_reg_rounded,
    BookingStepCode.declined => Icons.person_off_rounded,
    BookingStepCode.onTheWay => Icons.directions_walk_rounded,
    BookingStepCode.arrived => Icons.place_rounded,
    BookingStepCode.workStarted => Icons.play_arrow_rounded,
    BookingStepCode.workDone => Icons.task_alt_rounded,
    BookingStepCode.payment => Icons.payments_rounded,
    BookingStepCode.labourConfirm => Icons.verified_rounded,
    BookingStepCode.review => Icons.star_rounded,
    BookingStepCode.cancelled => Icons.close_rounded,
    BookingStepCode.terminated => Icons.report_gmailerrorred_rounded,
    BookingStepCode.unknown => Icons.circle_outlined,
  };

  ({Color dot, Color icon, Color text}) get _palette => switch (step.state) {
    BookingStepState.done => (
      dot: AppColors.yellow,
      icon: AppColors.black,
      text: AppColors.black,
    ),
    // The step the booking is sitting on. Black fill, yellow glyph — the same
    // inversion the app uses for "this one is yours to act on".
    BookingStepState.current => (
      dot: AppColors.black,
      icon: AppColors.yellow,
      text: AppColors.black,
    ),
    BookingStepState.failed => (
      dot: const Color(0xFFFDECEC),
      icon: AppColors.danger,
      text: AppColors.danger,
    ),
    BookingStepState.pending => (
      dot: AppColors.white,
      icon: AppColors.arrow,
      text: AppColors.muted,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final palette = _palette;
    final pending = step.state == BookingStepState.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                // Half-height connectors above and below the dot, so a step in
                // the middle of the list has one continuous line through it
                // regardless of how tall its text ran.
                SizedBox(
                  height: 9,
                  child: trailAbove == null
                      ? null
                      : _Trail(filled: trailAbove!),
                ),
                _Dot(
                  icon: _icon,
                  background: palette.dot,
                  foreground: palette.icon,
                  ringed: pending,
                  pulsing: step.isCurrent,
                ),
                if (!isLast)
                  Expanded(child: _Trail(filled: step.isReached)),
              ],
            ),
          ),
          Gap.hLg,
          Expanded(
            child: Padding(
              // Bottom padding rather than a gap between rows: the connector
              // has to run through the space, not stop short of it.
              padding: const EdgeInsets.only(bottom: Gap.x4l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          step.titleIn(s),
                          style: AppType.bodyStrong.copyWith(
                            color: palette.text,
                            fontWeight: step.isCurrent
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (step.at case final at?) ...[
                        Gap.hMd,
                        Text(
                          _clock(at, s),
                          style: AppType.micro.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (step.note case final note?) ...[
                    Gap.vXs,
                    Text(
                      note,
                      style: AppType.caption.copyWith(
                        color: step.hasFailed
                            ? AppColors.danger
                            : AppColors.muted,
                      ),
                    ),
                  ],
                  if (step.at case final at?) ...[
                    const SizedBox(height: Gap.xxs),
                    Text(
                      _relative(at, s),
                      style: AppType.nano.copyWith(color: AppColors.arrow),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// '10:42 AM', with the date in front once the step is not from today —
  /// a booking read back a week later needs to say which day.
  static String _clock(DateTime at, AppStrings s) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;

    final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final clock = '$hour12:$minute ${at.hour < 12 ? 'AM' : 'PM'}';

    return sameDay ? clock : '${at.day} ${s.monthsShort[at.month - 1]}, $clock';
  }

  /// 'Abhi abhi' / '20 min pehle' — how long ago, which is the thing somebody
  /// looking at a live job actually wants.
  static String _relative(DateTime at, AppStrings s) {
    final elapsed = DateTime.now().difference(at);

    if (elapsed.inMinutes < 1) return s.justNow;
    if (elapsed.inMinutes < 60) return s.minutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return s.hoursAgo(elapsed.inHours);
    return s.daysAgo(elapsed.inDays);
  }
}

class _Trail extends StatelessWidget {
  const _Trail({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedContainer(
      duration: Motion.normal,
      width: 2,
      color: filled ? AppColors.yellowDark : AppColors.border,
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.ringed,
    required this.pulsing,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  /// A step still ahead gets an outline rather than a fill.
  final bool ringed;

  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: ringed
            ? Border.all(color: AppColors.border, width: 1.5)
            : null,
      ),
      child: Icon(icon, size: 14, color: foreground),
    );

    // Only the step being waited on pulses — one moving thing on the screen,
    // and it is the one the Thekedar has to do something about.
    return pulsing
        ? PulseRings(color: AppColors.black, maxRadius: 18, child: dot)
        : dot;
  }
}
