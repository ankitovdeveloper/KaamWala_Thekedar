import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../core/tracking/tracking_session.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';
import 'widgets/arrival_sheet.dart';
import 'widgets/end_job_sheet.dart';
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
                // A refusal also has no position, so it has to be checked before
                // the null case below — otherwise a rejected request renders as
                // "waiting for them to accept", which is what it used to do.
                child: latest.declined
                    ? _RequestRejected(
                        name: widget.booking.labour.name,
                        at: latest.declinedAt,
                      )
                    : switch (latest.position) {
                        // No fix yet: the request is still with the worker, so
                        // there is nothing to plot and a map would just be an
                        // empty city.
                        null => _AwaitingAccept(
                          name: widget.booking.labour.name,
                        ),
                        final position => TrackingMap(
                          worker: position,
                          previous: _session.previous?.position,
                          destination:
                              latest.destination ?? widget.booking.site,
                          stage: latest.stage,
                          routePoints: _session.routePoints,
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
              // A timeline on a refused request would draw four steps that are
              // never going to happen. One line saying what became of it is the
              // whole story.
              if (update.declined)
                Padding(
                  padding: const EdgeInsets.only(top: Gap.xxl),
                  child: Text(
                    switch (update.declinedAt) {
                      final at? => '${s.rejectedTitle} · ${s.rejectedAt(_clock(at))}',
                      null => s.rejectedTitle,
                    },
                    style: AppType.bodyStrong.copyWith(
                      fontSize: 13,
                      color: AppColors.danger,
                    ),
                  ),
                )
              else ...[
                Gap.v20,
                StageTimeline(stage: update.stage, reached: update.accepted),
                ..._notes(update),
              ],
              if (update.termination case final ended?) ...[
                Gap.v20,
                _EndedNote(ended: ended),
              ],
              if (update.needsArrivalCode && update.accepted) ...[
                Gap.v20,
                // The one action on this screen. Deliberately available before
                // GPS says they have arrived: GPS fails, and a worker standing
                // in front of the Thekedar should not have to wait for a
                // satellite before the kaam can start.
                KwButton(
                  label: s.markArrived,
                  icon: Icons.how_to_reg_rounded,
                  variant: update.arrivedAt == null
                      ? KwButtonVariant.outline
                      : KwButtonVariant.yellow,
                  onPressed: () => _confirmArrival(update),
                ),
              ],
              // The kaam is under way, so the next thing that happens is it
              // finishing — and this screen is where the Thekedar is watching
              // from, so the button belongs here as well as in the list.
              if (update.stage == JobStage.working && !update.wasTerminated) ...[
                Gap.v20,
                KwButton(
                  label: s.markWorkDone,
                  icon: Icons.task_alt_rounded,
                  variant: KwButtonVariant.yellow,
                  onPressed: _completeJob,
                ),
              ],
              if (update.canTerminate) ...[
                Gap.vMd,
                // Quiet and text-only: this is the way out, not somewhere the
                // card is pushing anybody.
                Pressable(
                  onTap: _endJob,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                    child: Text(
                      s.endJob,
                      textAlign: TextAlign.center,
                      style: AppType.bodyStrong.copyWith(
                        fontSize: 13,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
              ],
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

  /// Opens the code sheet, and pulls a fresh sample the moment it succeeds so
  /// the timeline moves to Working without waiting for the next poll tick.
  Future<void> _confirmArrival(TrackingUpdate update) async {
    final started = await ArrivalSheet.show(
      context,
      repository: context.repo,
      bookingId: widget.booking.id,
      workerName: widget.booking.labour.name,
      gpsArrived: update.arrivedAt != null,
    );

    if (started == true) await _session.refresh();
  }

  /// Marks the kaam finished from here, behind a confirm: it ends the job for
  /// both sides and puts a confirmation prompt on the worker's screen.
  ///
  /// The session stops polling once the sample comes back completed, so the
  /// screen settles on the finished state by itself.
  Future<void> _completeJob() async {
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.markWorkDoneTitle, style: AppType.h4),
        content: Text(
          s.markWorkDoneMessage(widget.booking.labour.name),
          style: AppType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              s.notYet,
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              s.yesWorkDone,
              style: AppType.buttonSmall.copyWith(color: AppColors.successDark),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.repo.completeBooking(widget.booking.id);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s.workDoneMarked)));
      await _session.refresh();
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(describeError(context, e))));
    }
  }

  /// Opens the "stop this kaam" sheet, and pulls one more sample so the card
  /// switches to the stopped state without waiting for a tick.
  Future<void> _endJob() async {
    final ended = await EndJobSheet.show(
      context,
      repository: context.repo,
      bookingId: widget.booking.id,
      workerName: widget.booking.labour.name,
    );

    if (ended == true) await _session.refresh();
  }

  /// The captions under the timeline: how it got where it is, whether the dot on
  /// the map can be trusted, and what is being waited on.
  ///
  /// The worker no longer taps the middle stages — GPS moves "on the way", and
  /// the code below moves "working" — so the card owes the Thekedar those facts.
  /// A stale position is the failure mode that matters most: without it, a worker
  /// whose phone died looks like one who has stopped moving.
  List<Widget> _notes(TrackingUpdate update) {
    final s = context.s;
    final lines = <(String, Color)>[];

    if (update.accepted && !update.isLive) {
      lines.add((s.locationStale, AppColors.pendingText));
    }

    final arrivedAt = update.arrivedAt;

    if (update.needsArrivalCode && arrivedAt != null) {
      // They are here and the kaam is waiting on the Thekedar — the loudest
      // thing the caption can say, so it takes the success colour, not muted.
      lines.add((
        '${s.arrivedAt(_clock(arrivedAt))} · ${s.arrivalNeedsCode}',
        AppColors.successDark,
      ));
    } else if (update.stageWasAutomatic) {
      lines.add((s.stageAuto, AppColors.muted));
    } else if (update.arrivalConfirmedAt != null && arrivedAt != null) {
      lines.add((s.arrivedAt(_clock(arrivedAt)), AppColors.muted));
    }

    return [
      for (final (text, color) in lines) ...[
        Gap.vMd,
        Text(text, style: AppType.caption.copyWith(fontSize: 12, color: color)),
      ],
    ];
  }

  /// '09:40' — local, 24h, matching the times elsewhere in the app.
  String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

/// What happened when a job was stopped part-way.
///
/// Shown for both directions. When the *worker* ended it, this is the Thekedar's
/// only explanation for a dot that stopped moving, so the reason is the point of
/// the block rather than a footnote to it.
class _EndedNote extends StatelessWidget {
  const _EndedNote({required this.ended});

  final JobTermination ended;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final reason = ended.reason.isNotEmpty ? ended.reason : ended.reasonLabel;
    final worked = ended.workedLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.x3l),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: Radii.rSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stop_circle_outlined,
                size: 17,
                color: AppColors.danger,
              ),
              Gap.hSm,
              Expanded(
                child: Text(
                  ended.byThekedar ? s.endedByYou : s.endedByLabour,
                  style: AppType.bodyStrong.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            Gap.vMd,
            _row(s.endedReason, reason),
          ],
          if (worked.isNotEmpty) ...[
            Gap.vSm,
            _row(s.endedWorked, worked),
            Gap.vSm,
            // The app deliberately works out no part-day amount — that is
            // between the two of them — but it must not pretend the time did
            // not happen either.
            Text(
              s.endedPayNote,
              style: AppType.caption.copyWith(fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 110,
        child: Text(label, style: AppType.caption.copyWith(fontSize: 12)),
      ),
      Expanded(
        child: Text(
          value,
          style: AppType.bodyStrong.copyWith(fontSize: 12.5),
        ),
      ),
    ],
  );
}

/// The worker said no.
///
/// This screen used to have no way of showing that: the tracking endpoint
/// answered a declined booking with an error, and a failed poll looks exactly
/// like a lost connection — so the Thekedar was left watching "waiting for them
/// to accept" spin on a request that had already been refused. Now it is said
/// plainly, with a way straight back to looking for someone else.
class _RequestRejected extends StatelessWidget {
  const _RequestRejected({required this.name, this.at});

  final String name;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.x4l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cancel_outlined,
                size: 40,
                color: AppColors.danger,
              ),
              Gap.v20,
              Text(s.rejectedTitle, style: AppType.h3, textAlign: TextAlign.center),
              Gap.vXs,
              Text(
                s.rejectedBody(name),
                style: AppType.bodyMuted,
                textAlign: TextAlign.center,
              ),
              if (at case final when_?) ...[
                Gap.vXs,
                Text(
                  s.rejectedAt(
                    '${when_.hour.toString().padLeft(2, '0')}:'
                    '${when_.minute.toString().padLeft(2, '0')}',
                  ),
                  style: AppType.caption,
                ),
              ],
              Gap.v20,
              KwButton(
                label: s.findAnotherWorker,
                icon: Icons.search_rounded,
                // Straight to the search tab: the Thekedar still needs somebody
                // today, and the booking they were watching is closed.
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(Routes.home, (_) => false),
              ),
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
