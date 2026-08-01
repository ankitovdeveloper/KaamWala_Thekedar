import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
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

class _BookingsScreenState extends State<BookingsScreen> {
  BookingTab _tab = BookingTab.all;

  late final Loadable<List<Booking>> _bookings = Loadable(
    () => context.repo.bookings(tab: _tab.wire),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bookings.load();
    });
  }

  @override
  void dispose() {
    _bookings.dispose();
    super.dispose();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Booking cancel karein?', style: AppType.h4),
        content: Text(
          '${booking.labour.name} ki booking cancel ho jaayegi. '
          'Baar baar cancel karne se rating gir sakti hai.',
          style: AppType.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Rehne dein',
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Haan, cancel karein',
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
      _toast('Booking cancel ho gayi');
      _bookings.load(silent: true);
    } on Object catch (e) {
      if (mounted) _toast(describeError(e));
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
      _toast('${booking.labour.name} ko review de diya');
    } on Object catch (e) {
      if (mounted) _toast(describeError(e));
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
              child: Text('Meri Bookings', style: AppType.h2),
            ),
            const SizedBox(height: 2),
            FadeSlideIn(
              delay: const Duration(milliseconds: 70),
              from: SlideFrom.left,
              offset: 14,
              child: Text(
                _tab == BookingTab.all
                    ? '$active active · $done completed'
                    : '${rows.length} ${_tab.label.toLowerCase()}',
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
              onDetails: () => Navigator.of(
                context,
              ).pushNamed(Routes.labourDetail, arguments: booking.labour.id),
              onCancel: () => _cancel(booking),
              onReview: () => _review(booking),
            ),
          ),
        );
      },
    );
  }

  void _call(Booking booking) {
    // The API only reveals the number once the booking is accepted.
    final phone = booking.labourPhone;
    _toast(
      phone == null
          ? '${booking.labour.name} ka number booking accept hone par milega'
          : '${booking.labour.name}: $phone',
    );
  }

  Widget _empty() {
    final (title, message) = switch (_tab) {
      BookingTab.all => (
        'Abhi koi booking nahi',
        'Search se kaam wala chunein aur pehli booking karein.',
      ),
      BookingTab.active => (
        'Koi active booking nahi',
        'Confirmed bookings yahan dikhengi.',
      ),
      BookingTab.pending => (
        'Kuch pending nahi',
        'Jo request abhi accept nahi hui, wo yahan aayegi.',
      ),
      BookingTab.done => (
        'Abhi tak kuch complete nahi hua',
        'Poore hue kaam yahan history mein rahenge.',
      ),
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
                  'Kaam wale dhundein',
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
