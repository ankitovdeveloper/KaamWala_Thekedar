import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';

/// Re-builds [builder] with the time left until [expiresAt], and calls
/// [onExpired] once when it reaches zero.
///
/// The deadline is a point in time worked out from the server's "N seconds
/// left" (see `Booking.requestExpiresAt`), so everything here counts against
/// the local clock without ever trusting the phone's idea of the date.
///
/// The ticker stops by itself at zero: a countdown that is over costs nothing,
/// and a screen left open on an expired request is not still waking up.
class RequestCountdown extends StatefulWidget {
  const RequestCountdown({
    super.key,
    required this.expiresAt,
    required this.builder,
    this.onExpired,
  });

  final DateTime expiresAt;
  final Widget Function(BuildContext context, Duration left) builder;

  /// Called once, the first time the time left is zero. The caller decides what
  /// that means — usually one more look at the server, which is what actually
  /// cancels the request.
  final VoidCallback? onExpired;

  @override
  State<RequestCountdown> createState() => _RequestCountdownState();
}

class _RequestCountdownState extends State<RequestCountdown> {
  /// A deadline that moves by more than this is a different request, not the
  /// same one measured again.
  static const _newRequestGap = Duration(seconds: 3);

  Timer? _timer;
  bool _fired = false;

  /// The deadline being counted to. Held here rather than read off the widget:
  /// every reload hands this widget a fresh "N seconds left", rounded up by the
  /// server and received a moment late, so the deadline it implies wobbles by up
  /// to a second between polls — and a countdown that steps backwards looks
  /// broken. The earliest reading is the closest to the truth, so that is kept.
  late DateTime _deadline = widget.expiresAt;

  Duration get _left {
    final left = _deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RequestCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    final next = widget.expiresAt;
    if (next.isBefore(_deadline)) {
      _deadline = next;
    } else if (next.difference(_deadline) > _newRequestGap) {
      // A later deadline: a new request on the same screen.
      _deadline = next;
      _fired = false;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (_left == Duration.zero) {
      _expire();
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_left == Duration.zero) {
        _timer?.cancel();
        _timer = null;
        _expire();
      }
      setState(() {});
    });
  }

  void _expire() {
    if (_fired) return;
    _fired = true;
    // Out of the build/timer callback, so whatever the caller does with it (a
    // fetch, a navigation) never lands in the middle of this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExpired?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}

/// "0:14" — the whole seconds left, rounded up so it never reads 0:00 while
/// there is still a moment to answer.
String countdownLabel(Duration left) {
  final seconds = (left.inMilliseconds / 1000).ceil().clamp(0, 5999);
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The last few seconds are the ones that need noticing.
bool isRunningOut(Duration left) => left.inMilliseconds <= 5000;

/// A ring that drains, with the seconds left in the middle — the waiting
/// screen's one job is to say how long this will take.
class RequestCountdownRing extends StatelessWidget {
  const RequestCountdownRing({
    super.key,
    required this.expiresAt,
    required this.totalSeconds,
    this.onExpired,
    this.size = 112,
  });

  final DateTime expiresAt;
  final int totalSeconds;
  final VoidCallback? onExpired;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RequestCountdown(
      expiresAt: expiresAt,
      onExpired: onExpired,
      builder: (context, left) {
        final total = Duration(seconds: totalSeconds).inMilliseconds;
        final fraction = total == 0
            ? 0.0
            : (left.inMilliseconds / total).clamp(0.0, 1.0);
        final urgent = isRunningOut(left);
        final colour = urgent ? AppColors.danger : AppColors.yellowDark;
        final seconds = (left.inMilliseconds / 1000).ceil();

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(colour),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$seconds',
                    style: AppType.h1.copyWith(
                      fontSize: size * 0.34,
                      color: urgent ? AppColors.danger : AppColors.black,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text('sec', style: AppType.micro),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "⏱ 0:14 me jawab na aaya to cancel" — the one-line version, for a card.
class RequestCountdownLine extends StatelessWidget {
  const RequestCountdownLine({
    super.key,
    required this.expiresAt,
    required this.labelFor,
    this.onExpired,
  });

  final DateTime expiresAt;

  /// Wraps the formatted time in the sentence, in the user's language.
  final String Function(String time) labelFor;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    return RequestCountdown(
      expiresAt: expiresAt,
      onExpired: onExpired,
      builder: (context, left) {
        final urgent = isRunningOut(left);
        final colour = urgent ? AppColors.danger : AppColors.pendingText;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 13, color: colour),
            Gap.hXs,
            Flexible(
              child: Text(
                labelFor(countdownLabel(left)),
                style: AppType.micro.copyWith(
                  color: colour,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
