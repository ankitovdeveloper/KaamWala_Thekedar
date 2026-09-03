import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/async/loadable.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../data/repositories/kaamwala_repository.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';
import '../bookings/widgets/review_sheet.dart';
import '../tracking/widgets/arrival_sheet.dart';
import '../tracking/widgets/end_job_sheet.dart';
import 'widgets/booking_journey_map.dart';
import 'widgets/booking_timeline.dart';

/// One booking, whole — backed by `GET /v1/thekedar/bookings/{id}`.
///
/// This is what tapping a row in "Meri Bookings" opens. It used to open the
/// worker's profile, which answered a question nobody was asking: somebody
/// tapping a booking wants to know what happened *on that booking* — did he
/// turn up, when did the kaam start, has the money gone, who cancelled it and
/// why. The worker's record is on this screen too, as a section, with their
/// full profile one tap further on.
///
/// Every action the booking supports lives here as well, so the screen is not
/// a dead end you have to back out of to act. Which ones are offered is decided
/// by the server (`can`), not re-derived here — the two used to drift, and the
/// app found out by showing an error after the tap.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId, this.preview});

  final int bookingId;

  /// The row the list already has. Paints the header immediately while the full
  /// record loads underneath, so the screen never opens on a blank spinner.
  final Booking? preview;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen>
    with WidgetsBindingObserver {
  late final Loadable<BookingDetail> _detail = Loadable(
    () => context.repo.bookingDetail(widget.bookingId),
  );

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Half of what this screen shows is somebody else's to decide — the worker
    // accepting, setting off, signing the kaam off, or walking away. None of it
    // reaches the app on its own, so coming back to it is the moment to ask.
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detail.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detail.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _detail.load(silent: true);
  }

  Booking? get _booking => _detail.value?.booking ?? widget.preview;

  String get _workerName =>
      _detail.value?.labour.name ?? widget.preview?.labour.name ?? '';

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Runs one action, then refetches rather than patching a field.
  ///
  /// A patch would be wrong here: these endpoints move several columns at once
  /// (completing a job also stamps a start time, and puts a prompt on the
  /// worker's screen) and this screen renders the whole sequence. Guessing at
  /// the new timeline locally is exactly the kind of lie the screen exists to
  /// avoid.
  Future<void> _run(
    Future<void> Function(KaamWalaRepository repo) action,
    String toast,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      await action(context.repo);
      if (!mounted) return;
      _toast(toast);
      await _detail.load(silent: true);
    } on Object catch (e) {
      if (mounted) _toast(describeError(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Booking booking) async {
    final s = context.s;
    if (!await _ask(
      s.cancelBookingTitle,
      s.cancelBookingMessage(_workerName),
      s.yesCancel,
      danger: true,
    )) {
      return;
    }
    await _run((repo) => repo.cancelBooking(booking.id), s.bookingCancelled);
  }

  Future<void> _complete(Booking booking) async {
    final s = context.s;
    if (!await _ask(
      s.markWorkDoneTitle,
      s.markWorkDoneMessage(_workerName),
      s.yesWorkDone,
    )) {
      return;
    }
    await _run((repo) => repo.completeBooking(booking.id), s.workDoneMarked);
  }

  Future<void> _payment(Booking booking, int amount) async {
    final s = context.s;
    if (!await _ask(
      s.markPaymentTitle,
      s.markPaymentMessage(_workerName, amount),
      s.yesPaid,
    )) {
      return;
    }
    await _run((repo) => repo.markPaymentDone(booking.id), s.paymentDoneMarked);
  }

  Future<void> _review(Booking booking) async {
    final draft = await ReviewSheet.show(context, booking: booking);
    if (draft == null || !mounted) return;

    await _run(
      (repo) => repo.reviewBooking(
        bookingId: booking.id,
        rating: draft.rating,
        comment: draft.comment,
      ),
      context.s.reviewSubmitted(_workerName),
    );
  }

  /// The arrival handshake. The sheet owns the round trip — it has to show a
  /// wrong code and the attempt counter inline — so this only refetches after.
  Future<void> _confirmArrival() async {
    final confirmed = await ArrivalSheet.show(
      context,
      repository: context.repo,
      bookingId: widget.bookingId,
      workerName: _workerName,
    );
    if (confirmed != true || !mounted) return;

    _toast(context.s.arrivalDone);
    await _detail.load(silent: true);
  }

  Future<void> _endJob() async {
    final ended = await EndJobSheet.show(
      context,
      repository: context.repo,
      bookingId: widget.bookingId,
      workerName: _workerName,
    );
    if (ended != true || !mounted) return;

    await _detail.load(silent: true);
  }

  Future<void> _track(Booking booking) async {
    await Navigator.of(context).pushNamed(Routes.tracking, arguments: booking);
    if (!mounted) return;
    // Tracking is where a refusal or a stopped job is learned about, so coming
    // back from it is the one moment this screen is guaranteed to be stale.
    await _detail.load(silent: true);
  }

  void _openProfile(int labourId) =>
      Navigator.of(context).pushNamed(Routes.labourDetail, arguments: labourId);

  void _call(BookingDetail detail) {
    final phone = detail.labour.phone ?? detail.booking.labourPhone;
    _toast(
      phone == null
          ? context.s.numberAfterAccept(detail.labour.name)
          : '${detail.labour.name}: $phone',
    );
  }

  Future<bool> _ask(
    String title,
    String message,
    String confirmLabel, {
    bool danger = false,
  }) async {
    final s = context.s;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppType.h4),
        content: Text(message, style: AppType.bodyMuted),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              danger ? s.keepIt : s.notYet,
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel,
              style: AppType.buttonSmall.copyWith(
                color: danger ? AppColors.danger : AppColors.successDark,
              ),
            ),
          ),
        ],
      ),
    );
    return answer == true && mounted;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: ListenableBuilder(
        listenable: _detail,
        builder: (context, _) => Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final s = context.s;
    final booking = _booking;

    return KwHeader(
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            KwIconButton(
              icon: Icons.arrow_back_rounded,
              iconSize: 20,
              tooltip: s.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Gap.hXl,
            Expanded(
              child: FadeSlideIn(
                from: SlideFrom.left,
                offset: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.bookingDetailTitle,
                      style: AppType.h3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      s.bookingNumber(widget.bookingId),
                      style: AppType.micro.copyWith(
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (booking != null) ...[
              Gap.hMd,
              KwStatusBadge(
                label: _statusLabel(booking.status, s),
                tone: _statusTone(booking.status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final detail = _detail.value;

    if (detail == null) {
      if (_detail.error != null) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ApiErrorState(
            error: _detail.error!,
            onRetry: () => _detail.load(),
          ),
        );
      }
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _detail.load(silent: true),
      color: AppColors.black,
      backgroundColor: AppColors.yellow,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          Gap.x4l,
          context.pagePadding,
          Gap.x8l,
        ),
        children: [
          ContentWidth(
            child: Column(
              children: Stagger.wrap(
                base: const Duration(milliseconds: 90),
                offset: 20,
                children: [
                  if (_outcomeBanner(detail) case final banner?) ...[
                    banner,
                    Gap.vXl,
                  ],
                  _summaryCard(detail),
                  if (detail.locations.hasAny) ...[
                    Gap.vXl,
                    _section(context.s.bookingOnMap),
                    _mapCard(detail),
                  ],
                  Gap.vXl,
                  _section(context.s.bookingWhatHappened),
                  _timelineCard(detail),
                  Gap.vXl,
                  _section(context.s.bookingWorkerSection),
                  _workerCard(detail),
                  if (_actions(detail) case final actions when actions.isNotEmpty) ...[
                    Gap.v24,
                    ...actions,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.md),
    child: KwSectionTitle(title, padding: EdgeInsets.zero),
  );

  /// The one card that contradicts the rest of the screen, when there is one.
  ///
  /// A refusal, a stopped job, or a worker who signed the kaam off with a "no"
  /// are the things `status` alone cannot say: a disputed booking still reads
  /// "Completed · Payment done" everywhere else, because those columns record
  /// what was *declared*. This is the only place that says nobody agreed.
  Widget? _outcomeBanner(BookingDetail detail) {
    final s = context.s;
    final outcome = detail.outcome;
    final name = detail.labour.name;

    final (String title, String? body, IconData icon) = switch (outcome.kind) {
      BookingOutcomeKind.declined => (
        s.rejectedTitle,
        s.rejectedBody(name),
        Icons.person_off_rounded,
      ),
      BookingOutcomeKind.terminated => switch (outcome.termination) {
        final t? => (
          t.byLabour ? s.endedByLabour : s.endedByYou,
          [
            if (t.reason.isNotEmpty) '${s.endedReason}: ${t.reason}',
            if (t.workedLabel.isNotEmpty) '${s.endedWorked}: ${t.workedLabel}',
            s.endedPayNote,
          ].join('\n'),
          Icons.report_gmailerrorred_rounded,
        ),
        _ => (s.storyTerminated, null, Icons.report_gmailerrorred_rounded),
      },
      BookingOutcomeKind.cancelled => (
        s.storyCancelled,
        outcome.cancellationReason,
        Icons.event_busy_rounded,
      ),
      BookingOutcomeKind.disputed => (
        s.labourDisputed(name),
        outcome.completionRemark,
        Icons.gavel_rounded,
      ),
      // Not a failure, but it is the thing the Thekedar is waiting on, and it
      // is easy to miss halfway down a timeline.
      BookingOutcomeKind.completed when detail.payment.awaitingLabourConfirm => (
        s.awaitingLabourConfirm(name),
        null,
        Icons.hourglass_empty_rounded,
      ),
      _ => ('', null, Icons.info_outline),
    };

    if (title.isEmpty) return null;

    final bad = outcome.kind.isBad;

    return KwCard(
      color: bad ? const Color(0xFFFDECEC) : AppColors.yellowLight,
      borderColor: bad ? const Color(0x22D32F2F) : AppColors.yellowDark,
      padding: const EdgeInsets.all(Gap.x3l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: bad ? AppColors.danger : AppColors.pendingText,
          ),
          Gap.hXl,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppType.bodyStrong.copyWith(
                    color: bad ? AppColors.danger : AppColors.pendingText,
                  ),
                ),
                if (body != null && body.isNotEmpty) ...[
                  Gap.vXs,
                  Text(
                    body,
                    style: AppType.caption.copyWith(
                      color: bad
                          ? AppColors.danger.withValues(alpha: 0.85)
                          : AppColors.pendingText,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What was booked, and for how much.
  Widget _summaryCard(BookingDetail detail) {
    final s = context.s;
    final booking = detail.booking;
    final payment = detail.payment;

    return KwCard(
      padding: const EdgeInsets.all(Gap.x3l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              KwAvatar(
                initials: detail.labour.initials,
                photoUrl: detail.labour.photoUrl,
                size: 44,
                online: detail.labour.isOnDuty,
              ),
              Gap.hXl,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      detail.labour.name,
                      style: AppType.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      booking.skillName ??
                          detail.labour.primarySkillIn(s),
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
              Gap.hMd,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.xl,
                  vertical: Gap.xs,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: Radii.rPill,
                ),
                child: Text(
                  '₹${payment.amount}',
                  style: AppType.price.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          Gap.v16,
          const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          Gap.v16,
          _row(Icons.calendar_today_outlined, booking.whenLabelIn(s)),
          _row(Icons.schedule_rounded, booking.dayType.labelIn(s)),
          if (booking.address case final address?)
            _row(Icons.location_on_outlined, address),
          _row(
            payment.done
                ? Icons.check_circle_outline_rounded
                : Icons.payments_outlined,
            payment.done ? s.amountPaid : s.amountToPay,
            trailing: '₹${payment.amount}',
            tone: payment.done ? AppColors.successDark : null,
          ),
          // The number an argument starts from, when it is not the number that
          // was first offered.
          if (payment.wasNegotiated)
            _row(Icons.history_rounded, s.offeredWas(payment.offeredAmount)),
          if (booking.notes case final notes? when notes.isNotEmpty)
            _row(Icons.sticky_note_2_outlined, '${s.bookingNotesLabel}: $notes'),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String text, {
    String? trailing,
    Color? tone,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: tone ?? AppColors.muted),
          ),
          Gap.hMd,
          Expanded(
            child: Text(
              text,
              style: AppType.caption.copyWith(
                color: tone ?? AppColors.muted,
                fontSize: 12.5,
              ),
            ),
          ),
          if (trailing != null) ...[
            Gap.hMd,
            Text(
              trailing,
              style: AppType.bodyStrong.copyWith(
                fontSize: 13,
                color: tone ?? AppColors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapCard(BookingDetail detail) => KwCard(
    padding: const EdgeInsets.all(Gap.xl),
    child: BookingJourneyMap(
      locations: detail.locations,
      onTap: detail.can.track ? () => _track(detail.booking) : null,
    ),
  );

  Widget _timelineCard(BookingDetail detail) => KwCard(
    padding: const EdgeInsets.fromLTRB(Gap.x3l, Gap.x4l, Gap.x3l, Gap.md),
    child: BookingTimeline(steps: detail.timeline),
  );

  /// The worker, at the depth this screen needs — enough to decide whether to
  /// book them again, with their full profile one tap away.
  Widget _workerCard(BookingDetail detail) {
    final s = context.s;
    final labour = detail.labour;
    final phone = labour.phone ?? detail.booking.labourPhone;

    return KwCard(
      padding: const EdgeInsets.all(Gap.x3l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wrap rather than Row: five stars, a rating, a review count and the
          // duty chip do not fit across a 320pt phone, let alone at 1.3x font
          // scale. The chip drops to its own line instead of running off.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Gap.md,
            runSpacing: Gap.md,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KwStars(rating: labour.avgRating, size: 14, showEmpty: true),
                  Gap.hMd,
                  Text(
                    labour.avgRating.toStringAsFixed(1),
                    style: AppType.bodyStrong.copyWith(fontSize: 13),
                  ),
                  Gap.hXs,
                  Flexible(
                    child: Text(
                      s.reviewsCount(labour.ratingsCount),
                      style: AppType.micro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              KwAvailability(available: labour.isOnDuty),
            ],
          ),
          Gap.v16,
          Row(
            children: [
              _stat('${labour.experienceYears}', s.statYearsExperience),
              _stat('${labour.totalJobs}', s.statJobsDone),
              _stat('₹${labour.dailyRate}', s.perDay.replaceFirst('/ ', '')),
            ],
          ),
          if (labour.skills.isNotEmpty) ...[
            Gap.v16,
            Wrap(
              spacing: Gap.md,
              runSpacing: Gap.md,
              children: [
                for (final skill in labour.skills)
                  KwPill(label: skill.name, dense: true),
              ],
            ),
          ],
          if (labour.bio case final bio? when bio.isNotEmpty) ...[
            Gap.v16,
            Text(bio, style: AppType.caption.copyWith(height: 1.5)),
          ],
          Gap.v16,
          const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          Gap.vXl,
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.md,
            children: [
              KwChipButton(
                label: phone ?? s.contactAfterBooking,
                icon: Icons.phone_outlined,
                filled: phone != null,
                onPressed: () => _call(detail),
              ),
              KwChipButton(
                label: s.openFullProfile,
                icon: Icons.person_outline_rounded,
                onPressed: () => _openProfile(labour.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppType.statNumber.copyWith(fontSize: 18)),
        Text(
          label,
          style: AppType.nano.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ],
    ),
  );

  /// The buttons, in the order the job actually moves.
  ///
  /// The primary one is whatever the booking is waiting on; the rest are chips
  /// under it. Nothing is offered that the server did not say was on.
  List<Widget> _actions(BookingDetail detail) {
    final s = context.s;
    final can = detail.can;
    final booking = detail.booking;

    // Whatever the booking is actually waiting on, in the order the job moves.
    // Typing the worker's four digits comes first while it is owed: it is the
    // only thing that can start a kaam, and nothing else moves until it is done.
    final ({String label, IconData icon, VoidCallback onTap})? primary;
    if (can.confirmArrival) {
      primary = (
        label: s.markArrived,
        icon: Icons.how_to_reg_rounded,
        onTap: _confirmArrival,
      );
    } else if (can.track) {
      primary = (
        label: s.liveTrack,
        icon: Icons.near_me_rounded,
        onTap: () => _track(booking),
      );
    } else if (can.markPayment) {
      primary = (
        label: s.markPaymentDone,
        icon: Icons.payments_outlined,
        onTap: () => _payment(booking, detail.payment.amount),
      );
    } else if (can.review) {
      primary = (
        label: s.giveReview,
        icon: Icons.star_outline_rounded,
        onTap: () => _review(booking),
      );
    } else {
      primary = null;
    }

    final secondary = <Widget>[
      // Not offered next to "mark arrived": a job whose start has not been
      // confirmed cannot be finished, and the server refuses it anyway.
      if (can.complete && !can.confirmArrival)
        KwChipButton(
          label: s.markWorkDone,
          icon: Icons.task_alt_rounded,
          onPressed: () => _complete(booking),
        ),
      if (can.markPayment && primary?.label != s.markPaymentDone)
        KwChipButton(
          label: s.markPaymentDone,
          icon: Icons.payments_outlined,
          onPressed: () => _payment(booking, detail.payment.amount),
        ),
      if (can.review && primary?.label != s.giveReview)
        KwChipButton(
          label: s.giveReview,
          icon: Icons.star_outline_rounded,
          onPressed: () => _review(booking),
        ),
      if (can.terminate)
        KwChipButton(
          label: s.endJob,
          icon: Icons.block_rounded,
          danger: true,
          onPressed: _endJob,
        ),
      if (can.cancel)
        KwChipButton(
          label: s.cancel,
          danger: true,
          onPressed: () => _cancel(booking),
        ),
      // Nothing left to do but book them again.
      if (!can.cancel && !can.track && !can.complete && !can.markPayment)
        KwChipButton(
          label: s.bookAgain,
          icon: Icons.replay_rounded,
          onPressed: () => _openProfile(detail.labour.id),
        ),
    ];

    return [
      if (primary case final action?) ...[
        KwButton(
          label: action.label,
          icon: action.icon,
          size: KwButtonSize.large,
          busy: _busy,
          onPressed: action.onTap,
        ),
        Gap.v16,
      ],
      if (secondary.isNotEmpty)
        Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: secondary,
        ),
    ];
  }

  static String _statusLabel(BookingStatus status, AppStrings s) =>
      switch (status) {
        BookingStatus.accepted => s.statusConfirmed,
        BookingStatus.pending => s.statusPending,
        BookingStatus.completed => s.statusCompleted,
        BookingStatus.cancelled => s.statusCancelled,
        BookingStatus.declined => s.statusDeclined,
      };

  static KwStatusTone _statusTone(BookingStatus status) => switch (status) {
    BookingStatus.accepted => KwStatusTone.confirmed,
    BookingStatus.pending => KwStatusTone.pending,
    BookingStatus.completed => KwStatusTone.done,
    BookingStatus.cancelled || BookingStatus.declined => KwStatusTone.cancelled,
  };
}
