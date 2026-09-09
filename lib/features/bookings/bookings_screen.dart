import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/async/live_poll.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/repositories/kaamwala_repository.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_celebration.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';
import '../shell/home_shell.dart';
import 'widgets/booking_card.dart';
import 'widgets/booking_tabs.dart';
import 'widgets/review_sheet.dart';

/// "Meri Bookings", backed by `GET /v1/thekedar/bookings?tab=`.
///
/// The tab is a server-side filter, so switching tabs refetches rather than
/// filtering a cached list — that keeps counts honest when another device (or
/// the labour app) changes a booking.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with WidgetsBindingObserver {
  BookingTab _tab = BookingTab.all;

  late final Loadable<List<Booking>> _bookings = Loadable(
    () => context.repo.bookings(tab: _tab.wire),
  );

  /// Keeps the rows honest while somebody is looking at them. The stage strip
  /// on an accepted card is moved by the worker's phone, not by anything that
  /// happens here, so without this the card sits on "Pending" until the app is
  /// backgrounded and reopened — which is not how anybody waits for a labour
  /// to set off.
  late final LivePoll _live = LivePoll(
    onTick: _pollLive,
    interval: ApiConfig.stagePollInterval,
  );

  @override
  void initState() {
    super.initState();
    // Every row here is a decision somebody else can make: the worker accepts,
    // refuses, or walks off, and none of it reaches this screen on its own.
    // Coming back to the app is the moment to find out.
    WidgetsBinding.instance.addObserver(this);
    // ...and while the app *is* open, the timer is. Synced off the loaded rows
    // so it only runs while one of them is still live.
    _bookings.addListener(_syncLive);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bookings.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.dispose();
    _bookings.removeListener(_syncLive);
    _bookings.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Silent: the rows already on screen stay up while the new ones land.
    if (state == AppLifecycleState.resumed) {
      _live.resume();
      _bookings.load(silent: true);
    } else {
      _live.pause();
    }
  }

  /// Runs the timer for exactly as long as a row can still move on its own.
  void _syncLive() => _live.sync(wanted: _rows.any((b) => b.isLive));

  /// One tick: refetch quietly, then say so if a worker set off while the
  /// Thekedar was watching the list.
  Future<void> _pollLive() async {
    final before = {for (final b in _rows) b.id: b.jobStage};
    await _bookings.load(silent: true);
    if (!mounted) return;

    // Only the screen on top gets to interrupt, and only the first departure —
    // a queue of these would bury the one that just happened.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    for (final booking in _rows) {
      if (before[booking.id] == JobStage.pending &&
          booking.jobStage == JobStage.onTheWay) {
        _toast(context.s.labourOnTheWay(booking.labour.name));
        return;
      }
    }
  }

  void _selectTab(BookingTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _bookings.refetchWith(() => context.repo.bookings(tab: tab.wire));
  }

  List<Booking> get _rows => _bookings.value ?? const [];

  /// Counts come from whatever the current tab returned, so they're only shown
  /// on the "Sab" tab where the list is the full set.
  Map<BookingTab, int> get _counts {
    if (_tab != BookingTab.all) return const {};
    final rows = _rows;
    return {
      BookingTab.all: rows.length,
      BookingTab.active: rows
          .where((b) => b.status == BookingStatus.accepted)
          .length,
      BookingTab.pending: rows
          .where((b) => b.status == BookingStatus.pending)
          .length,
      BookingTab.done: rows.where((b) => b.isDone).length,
    };
  }

  Future<void> _cancel(Booking booking) async {
    final s = context.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.cancelBookingTitle, style: AppType.h4),
        content: Text(
          s.cancelBookingMessage(booking.labour.name),
          style: AppType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              s.keepIt,
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              s.yesCancel,
              style: AppType.buttonSmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final updated = await context.repo.cancelBooking(booking.id);
      if (!mounted) return;
      // Patch in place so the row doesn't jump while the list refreshes.
      _bookings.setValue([
        for (final b in _rows)
          if (b.id == booking.id) updated else b,
      ]);
      _toast(s.bookingCancelled);
      _bookings.load(silent: true);
    } on Object catch (e) {
      if (mounted) _toast(describeError(context, e));
    }
  }

  /// "Kaam poora hua". Behind a confirm because it ends the job for both sides
  /// and puts a confirmation prompt on the worker's screen — not something to
  /// fire off a stray tap in a list.
  Future<void> _complete(Booking booking) async {
    final s = context.s;
    if (!await _ask(s.markWorkDoneTitle, s.markWorkDoneMessage(booking.labour.name),
        s.yesWorkDone)) {
      return;
    }
    await _apply(
      booking,
      (repo) => repo.completeBooking(booking.id),
      () => KwCelebration.show(
        context,
        title: s.celebrateWorkDoneTitle,
        message: s.celebrateWorkDoneBody(booking.labour.name),
      ),
    );
  }

  /// "Payment done". Same reasoning, and the same prompt lands on the worker's
  /// side — they are the ones who have to say the money actually arrived.
  Future<void> _paymentDone(Booking booking) async {
    final s = context.s;
    if (!await _ask(s.markPaymentTitle,
        s.markPaymentMessage(booking.labour.name, booking.price), s.yesPaid)) {
      return;
    }
    await _apply(
      booking,
      (repo) => repo.markPaymentDone(booking.id),
      () => KwCelebration.show(
        context,
        title: s.celebratePaymentTitle,
        message: s.celebratePaymentBody(booking.labour.name),
        detail: '₹${booking.price}',
        detailIcon: Icons.payments_rounded,
      ),
    );
  }

  /// Yes/no dialog shared by the two wrap-up actions.
  Future<bool> _ask(String title, String message, String confirmLabel) async {
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
              s.notYet,
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel,
              style: AppType.buttonSmall.copyWith(color: AppColors.successDark),
            ),
          ),
        ],
      ),
    );
    return answer == true && mounted;
  }

  /// Runs one booking action, patches the row in place so it does not jump, and
  /// refreshes quietly behind it.
  ///
  /// [announce] rather than a toast string: both callers land on a moment worth
  /// a celebration, and the popup has to open *after* the row has been patched
  /// so the list behind the confetti already reads right.
  Future<void> _apply(
    Booking booking,
    Future<Booking> Function(KaamWalaRepository repo) action,
    Future<void> Function() announce,
  ) async {
    try {
      final updated = await action(context.repo);
      if (!mounted) return;
      _bookings.setValue([
        for (final b in _rows)
          if (b.id == booking.id) updated else b,
      ]);
      _bookings.load(silent: true);
      await announce();
    } on Object catch (e) {
      if (mounted) _toast(describeError(context, e));
    }
  }

  Future<void> _review(Booking booking) async {
    final result = await ReviewSheet.show(context, booking: booking);
    if (result == null || !mounted) return;

    try {
      await context.repo.reviewBooking(
        bookingId: booking.id,
        rating: result.rating,
        comment: result.comment,
      );
      if (!mounted) return;
      _bookings.setValue([
        for (final b in _rows)
          if (b.id == booking.id) b.copyWith(hasReview: true) else b,
      ]);
      final s = context.s;
      await KwCelebration.show(
        context,
        title: s.celebrateReviewTitle,
        message: s.celebrateReviewBody(booking.labour.name),
        detail: '${result.rating} ★',
        detailIcon: Icons.star_rounded,
      );
    } on Object catch (e) {
      if (mounted) _toast(describeError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: ListenableBuilder(
        listenable: _bookings,
        builder: (context, _) {
          final rows = _rows;

          return Column(
            children: [
              _header(rows),
              BookingTabs(
                current: _tab,
                onChanged: _selectTab,
                counts: _counts,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _bookings.load(silent: true),
                  color: AppColors.black,
                  backgroundColor: AppColors.yellow,
                  child: AnimatedSwitcher(
                    duration: Motion.normal,
                    switchInCurve: Motion.enter,
                    switchOutCurve: Motion.exit,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _body(rows),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(List<Booking> rows) {
    if (_bookings.isInitialLoad) {
      return const Center(
        key: ValueKey('loading'),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      );
    }
    if (_bookings.error != null && rows.isEmpty) {
      return SingleChildScrollView(
        key: const ValueKey('error'),
        physics: const AlwaysScrollableScrollPhysics(),
        child: ApiErrorState(
          error: _bookings.error!,
          onRetry: () => _bookings.load(),
        ),
      );
    }
    return rows.isEmpty ? _empty() : _list(rows);
  }

  Widget _header(List<Booking> rows) {
    final s = context.s;
    final active = rows.where((b) => b.status == BookingStatus.accepted).length;
    final done = rows.where((b) => b.isDone).length;

    return KwHeader(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              from: SlideFrom.left,
              offset: 14,
              child: Text(s.myBookings, style: AppType.h2),
            ),
            const SizedBox(height: 2),
            FadeSlideIn(
              delay: const Duration(milliseconds: 70),
              from: SlideFrom.left,
              offset: 14,
              child: Text(
                _tab == BookingTab.all
                    ? s.bookingsSummary(active, done)
                    : '${rows.length} ${_tab.labelIn(s).toLowerCase()}',
                style: AppType.micro.copyWith(
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Booking> rows) {
    return ListView.builder(
      key: ValueKey('list-${_tab.name}'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        Gap.xxl,
        context.pagePadding,
        Gap.x7l,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final booking = rows[i];
        return ContentWidth(
          child: FadeSlideIn.staggered(
            key: ValueKey('booking-${booking.id}'),
            index: i,
            beginScale: 0.97,
            child: BookingCard(
              booking: booking,
              onCall: () => _call(booking),
              onDetails: () => _details(booking),
              onBookAgain: () => Navigator.of(
                context,
              ).pushNamed(Routes.labourDetail, arguments: booking.labour.id),
              onCancel: () => _cancel(booking),
              onReview: () => _review(booking),
              onComplete: () => _complete(booking),
              onPaymentDone: () => _paymentDone(booking),
              // The tracking screen is where a refusal or a stopped job is
              // learned about, so coming back from it is the one moment this
              // list is guaranteed to be out of date.
              onTrack: () => _track(booking),
            ),
          ),
        );
      },
    );
  }

  /// The booking's own record. Every action lives on that screen too, so
  /// anything could have moved while it was open — hence the refetch on return.
  Future<void> _details(Booking booking) async {
    await Navigator.of(
      context,
    ).pushNamed(Routes.bookingDetail, arguments: booking);
    if (mounted) _bookings.load(silent: true);
  }

  Future<void> _track(Booking booking) async {
    await Navigator.of(
      context,
    ).pushNamed(Routes.tracking, arguments: booking);
    if (mounted) _bookings.load(silent: true);
  }

  void _call(Booking booking) {
    // The API only reveals the number once the booking is accepted.
    final phone = booking.labourPhone;
    _toast(
      phone == null
          ? context.s.numberAfterAccept(booking.labour.name)
          : '${booking.labour.name}: $phone',
    );
  }

  Widget _empty() {
    final s = context.s;
    final (title, message) = switch (_tab) {
      BookingTab.all => (s.emptyAllTitle, s.emptyAllMessage),
      BookingTab.active => (s.emptyActiveTitle, s.emptyActiveMessage),
      BookingTab.pending => (s.emptyPendingTitle, s.emptyPendingMessage),
      BookingTab.done => (s.emptyDoneTitle, s.emptyDoneMessage),
    };

    return SingleChildScrollView(
      key: ValueKey('empty-${_tab.name}'),
      physics: const AlwaysScrollableScrollPhysics(),
      child: KwEmptyState(
        icon: Icons.event_note_rounded,
        title: title,
        message: message,
        action: _tab == BookingTab.all
            ? TextButton(
                onPressed: () => HomeShell.of(context)?.goToTab(0),
                child: Text(
                  s.findLabour,
                  style: AppType.buttonSmall.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
