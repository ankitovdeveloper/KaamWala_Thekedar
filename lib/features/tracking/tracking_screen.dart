import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/tracking/tracking_session.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';
import 'widgets/tracking_map.dart';
import 'widgets/stage_timeline.dart';

/// Live tracking for an accepted booking — the map fills the screen and a card
/// over it carries the ETA, the worker, and how far along the job is.
///
/// Polling starts when the screen opens and stops when it closes or the job
/// completes, so nothing keeps hitting the server in the background.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  late final TrackingSession _session;

  @override
  void initState() {
    super.initState();
    _session = TrackingSession(
      repository: context.repo,
      bookingId: widget.booking.id,
    )..start();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final fatal = _session.fatalError;
          if (fatal != null) {
            return _withHeader(
              ApiErrorState(error: fatal, onRetry: _session.refresh),
            );
          }

          final latest = _session.latest;
          if (latest == null) {
            return _withHeader(
              const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: switch (latest.position) {
                  // No fix yet: the request is still with the worker, so there
                  // is nothing to plot and a map would just be an empty city.
                  null => _AwaitingAccept(name: widget.booking.labour.name),
                  final position => TrackingMap(
                    worker: position,
                    previous: _session.previous?.position,
                    destination: latest.destination ?? widget.booking.site,
                    stage: latest.stage,
                  ),
                },
              ),
              Positioned(top: 0, left: 0, right: 0, child: _header()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _statusCard(latest),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _withHeader(Widget child) => Column(
    children: [
      _header(),
      Expanded(child: child),
    ],
  );

  Widget _header() => KwHeader(
    padding: const EdgeInsets.fromLTRB(10, 10, 18, 12),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: AppColors.black,
            tooltip: context.s.back,
          ),
          Expanded(
            child: FadeSlideIn(
              from: SlideFrom.left,
              offset: 12,
              child: Text(context.s.liveTracking, style: AppType.h2),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _statusCard(TrackingUpdate update) {
    final s = context.s;
    final booking = widget.booking;
    final eta = update.etaLabelIn(s);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: KwCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KwAvatar(initials: booking.labour.initials, online: true),
                  Gap.hXl,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(booking.labour.name, style: AppType.bodyStrong),
                        if (booking.skillName case final skill?)
                          Text(skill, style: AppType.caption),
                      ],
                    ),
                  ),
                  // The ETA is the one number people come back to this screen
                  // for, so it gets the loudest treatment in the card.
                  AnimatedSwitcher(
                    duration: Motion.fast,
                    child: Column(
                      key: ValueKey(eta),
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(eta, style: AppType.bodyStrong),
                        if (update.distanceKm case final km?
                            when update.stage == JobStage.onTheWay)
                          Text(
                            km < 1
                                ? '${(km * 1000).round()} m'
                                : '${km.toStringAsFixed(1)} km',
                            style: AppType.caption.copyWith(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Gap.v20,
              StageTimeline(stage: update.stage, reached: update.accepted),
              if (_session.error != null) ...[
                Gap.vMd,
                // A failed poll keeps the last position on screen; saying so is
                // better than letting a frozen marker look like a stopped van.
                Text(
                  s.trackingStalled,
                  style: AppType.caption.copyWith(
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The gap between sending a request and the worker answering it.
///
/// Deliberately not a map: plotting the worker here would suggest they had
/// already taken the job and set off.
class _AwaitingAccept extends StatelessWidget {
  const _AwaitingAccept({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surfaceAlt,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.x4l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            Gap.v20,
            Text(
              context.s.requestSent,
              style: AppType.h3,
              textAlign: TextAlign.center,
            ),
            Gap.vXs,
            Text(
              context.s.awaitingAccept(name),
              style: AppType.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
