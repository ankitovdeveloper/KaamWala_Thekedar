import 'package:flutter/material.dart';

import '../../core/animations/effects.dart';
import '../../core/animations/entrance.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';
import 'widgets/booking_sheet.dart';

/// Worker profile, backed by `GET /v1/thekedar/labour/{id}`.
///
/// [preview] is the row from the search list: enough to paint the header
/// immediately (and fly the Hero) while the full record — bio, reviews, job
/// count — loads underneath.
///
/// Set [embedded] when this renders inside the wide-screen search pane: it
/// drops the back button and the Hero, since there's no route flight.
class LabourDetailScreen extends StatefulWidget {
  const LabourDetailScreen({
    super.key,
    required this.labourId,
    this.preview,
    this.embedded = false,
  });

  final int labourId;
  final Labour? preview;
  final bool embedded;

  @override
  State<LabourDetailScreen> createState() => _LabourDetailScreenState();
}

class _LabourDetailScreenState extends State<LabourDetailScreen> {
  final _scroll = ScrollController();
  late final Loadable<Labour> _detail = Loadable(
    () => context.repo.labourDetail(widget.labourId),
  );

  double _offset = 0;
  bool _booked = false;
  bool _savingFavourite = false;

  static const _heroHeight = 226.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (mounted) setState(() => _offset = _scroll.offset);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _detail.load();
    });
  }

  @override
  void didUpdateWidget(covariant LabourDetailScreen old) {
    super.didUpdateWidget(old);
    // The two-pane layout reuses this screen for a different worker.
    if (widget.labourId != old.labourId) {
      _booked = false;
      _detail.refetchWith(
        () => context.repo.labourDetail(widget.labourId),
        silent: false,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _detail.dispose();
    super.dispose();
  }

  /// Full record once loaded, else the list row, else nothing to paint yet.
  Labour? get _labour => _detail.value ?? widget.preview;

  Future<void> _book(Labour labour) async {
    final booking = await BookingSheet.show(context, labour: labour);
    if (booking == null || !mounted) return;

    setState(() => _booked = true);

    // Straight into tracking: the request is now with the worker, and this is
    // the screen that shows their answer arriving and then where they are.
    Navigator.of(context).pushNamed(Routes.tracking, arguments: booking);
  }

  Future<void> _toggleSaved(Labour labour) async {
    if (_savingFavourite) return;
    setState(() => _savingFavourite = true);

    try {
      final saved = await context.repo.toggleSaved(labour.id);
      if (!mounted) return;
      _detail.setValue(labour.copyWith(isSaved: saved));
      _toast(
        saved
            ? context.s.savedAdded(labour.name)
            : context.s.savedRemoved(labour.name),
      );
    } on Object catch (e) {
      if (mounted) _toast(describeError(context, e));
    } finally {
      if (mounted) setState(() => _savingFavourite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _detail,
      builder: (context, _) {
        final labour = _labour;

        final Widget body;
        if (labour == null) {
          body = _detail.error != null
              ? ApiErrorState(
                  error: _detail.error!,
                  onRetry: () => _detail.load(),
                )
              : const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                );
        } else {
          body = Stack(
            children: [
              _scrollBody(labour),
              Positioned(left: 0, right: 0, bottom: 0, child: _bookBar(labour)),
            ],
          );
        }

        if (widget.embedded) {
          return ColoredBox(color: AppColors.canvas, child: body);
        }
        return KwScaffold(body: body);
      },
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _scrollBody(Labour l) {
    // Parallax: the header drifts up at half the scroll rate and fades out.
    final parallax = (_offset * 0.5).clamp(0.0, _heroHeight);
    final fade = (1 - _offset / 150).clamp(0.0, 1.0);

    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(0, -parallax),
              child: Opacity(opacity: fade, child: _hero(l)),
            ),
          ),
        ),
        SliverContentWidth(
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              Gap.x3l,
              context.pagePadding,
              // Room for the sticky CTA plus the shell's nav bar.
              110,
            ),
            sliver: SliverList.list(
              children: Stagger.wrap(
                base: const Duration(milliseconds: 120),
                offset: 22,
                children: [
                  _statsRow(l),
                  Gap.vXl,
                  _detailsCard(l),
                  Gap.vXl,
                  if (l.bio != null) ...[_aboutCard(l), Gap.vXl],
                  Text(context.s.recentReviews, style: AppType.bodyStrong),
                  Gap.vLg,
                  ..._reviews(l),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(Labour l) {
    final s = context.s;
    return Container(
      width: double.infinity,
      color: AppColors.yellow,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Gap.vXxl,
            Row(
              children: [
                if (!widget.embedded) ...[
                  KwIconButton(
                    icon: Icons.arrow_back_rounded,
                    iconSize: 20,
                    tooltip: s.back,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Gap.hXl,
                ],
                Expanded(
                  child: Text(
                    s.labourDetail,
                    style: AppType.h4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                KwIconButton(
                  icon: l.isSaved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  tooltip: l.isSaved ? s.removeFromSaved : s.saveToList,
                  onPressed: () => _toggleSaved(l),
                ),
                Gap.hMd,
                KwIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: s.share,
                  onPressed: () => _toast(s.shareLinkCopied),
                ),
              ],
            ),
            Gap.v20,
            _heroAvatar(l),
            Gap.vXl,
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              offset: 10,
              child: Text(
                l.name,
                style: AppType.h2,
                textAlign: TextAlign.center,
              ),
            ),
            Gap.vXs,
            FadeSlideIn(
              delay: const Duration(milliseconds: 130),
              offset: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KwStars(
                    rating: l.avgRating,
                    size: 16,
                    color: AppColors.black,
                    showEmpty: true,
                  ),
                  Gap.hSm,
                  Text(
                    l.avgRating.toStringAsFixed(1),
                    style: AppType.bodyStrong.copyWith(fontSize: 14),
                  ),
                  Gap.hXs,
                  // Review count is the least important part of the line, so
                  // it's the piece that gives way on a narrow screen.
                  Flexible(
                    child: Text(
                      s.reviewsCount(l.ratingsCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.micro.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroAvatar(Labour l) {
    final avatar = KwAvatar(
      initials: l.initials,
      size: 80,
      background: AppColors.black,
      foreground: AppColors.yellow,
      ring: AppColors.veil06,
    );

    if (widget.embedded) return avatar;

    return Hero(
      tag: 'labour-avatar-${l.id}',
      flightShuttleBuilder: (_, animation, _, _, _) {
        // Grow the monogram smoothly rather than letting the text jump size.
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) => KwAvatar(
            initials: l.initials,
            size: 50 + 30 * animation.value,
            background: AppColors.black,
            foreground: AppColors.yellow,
          ),
        );
      },
      child: avatar,
    );
  }

  // ── Body cards ────────────────────────────────────────────────────────────

  Widget _statsRow(Labour l) {
    final s = context.s;
    final items = <(num, String, String)>[
      (l.experienceYears, '+', s.statYearsExperience),
      (l.totalJobs, '', s.statJobsDone),
      (l.ratingsCount, '', s.statReviewsGot),
    ];

    // Equal-height boxes even when one label wraps to two lines.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Gap.hLg,
            Expanded(
              child: KwCard(
                padding: const EdgeInsets.symmetric(vertical: Gap.xl),
                radius: Radii.rSm,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountUp(
                      value: items[i].$1,
                      suffix: items[i].$2,
                      delay: Duration(milliseconds: 200 + i * 90),
                      style: AppType.statNumber,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$3,
                      style: AppType.micro.copyWith(height: 1.25),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailsCard(Labour l) {
    final s = context.s;
    final distance = l.distanceLabelIn(s);

    return KwMenuCard(
      margin: EdgeInsets.zero,
      children: [
        if (l.city != null || l.address != null)
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: s.locationAddress,
            value: l.address ?? l.city!,
            hint: distance == null ? null : s.awayFromYou(distance),
          ),
        _DetailRow(
          icon: Icons.currency_rupee_rounded,
          label: s.todayRate,
          valueWidget: Row(
            children: [
              Text(
                '₹${l.dailyRate}',
                style: AppType.bodyStrong.copyWith(fontSize: 20),
              ),
              Gap.hLg,
              KwPill(label: s.perDay, background: AppColors.yellow),
            ],
          ),
        ),
        if (l.skills.isNotEmpty)
          _DetailRow(
            icon: Icons.handyman_outlined,
            label: s.skills,
            valueWidget: Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final s in l.skills)
                  KwPill(label: s.label, background: AppColors.yellowLight),
              ],
            ),
          ),
        _DetailRow(
          icon: Icons.schedule_rounded,
          label: s.availabilityToday,
          valueWidget: KwAvailability(
            available: l.isOnDuty,
            label: l.isOnDuty ? s.availableCallNow : s.notOnDuty,
            fontSize: 13,
          ),
          hint: l.timing == null ? null : s.timingLine(l.timing!),
        ),
        _DetailRow(
          icon: Icons.badge_outlined,
          label: s.experience,
          value: s.years(l.experienceYears),
        ),
        _DetailRow(
          icon: Icons.phone_outlined,
          // The API hides the number until a booking exists between the two.
          label: s.contact,
          value: l.contactUnlocked && l.phone != null
              ? l.phone!
              : s.contactAfterBooking,
          last: true,
        ),
      ],
    );
  }

  Widget _aboutCard(Labour l) {
    return KwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.s.aboutMe, style: AppType.label),
          Gap.vSm,
          Text(l.bio!, style: AppType.body.copyWith(fontSize: 13)),
        ],
      ),
    );
  }

  List<Widget> _reviews(Labour l) {
    // Reviews only arrive with the detail payload, so a preview shows a
    // placeholder rather than claiming there are none.
    if (l.reviews.isEmpty) {
      return [
        KwCard(
          child: Row(
            children: [
              Icon(
                _detail.isLoading
                    ? Icons.hourglass_empty_rounded
                    : Icons.reviews_outlined,
                size: 20,
                color: AppColors.muted,
              ),
              Gap.hXl,
              Expanded(
                child: Text(
                  _detail.isLoading
                      ? context.s.reviewsLoading
                      : context.s.noReviewsYet,
                  style: AppType.caption,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      for (final r in l.reviews)
        KwCard(
          margin: const EdgeInsets.only(bottom: Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.reviewerName,
                      style: AppType.bodyStrong.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  KwStars(rating: r.rating.toDouble(), size: 13),
                ],
              ),
              if (r.comment != null) ...[
                Gap.vSm,
                Text(
                  r.comment!,
                  style: AppType.body.copyWith(fontSize: 13, height: 1.5),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  // ── Sticky CTA ────────────────────────────────────────────────────────────

  Widget _bookBar(Labour l) {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 260),
      offset: 30,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -3),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          Gap.x3l,
          Gap.xxl,
          Gap.x3l,
          // Pushed above the system gesture bar when this is a page of its
          // own. Embedded in the search pane, the shell's nav bar already
          // owns that inset, so adding it again would just leave a gap.
          Gap.xxl +
              (widget.embedded ? 0 : MediaQuery.viewPaddingOf(context).bottom),
        ),
        child: ContentWidth(
          child: KwButton(
            label: _booked
                ? context.s.bookingSent
                : context.s.bookNow(l.dailyRate),
            icon: Icons.event_available_rounded,
            size: KwButtonSize.large,
            succeeded: _booked,
            onPressed: _booked ? null : () => _book(l),
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// One labelled row inside the details card.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.hint,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? hint;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.x3l,
            vertical: 13,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 20, color: AppColors.black),
              ),
              Gap.hXl,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: AppType.label),
                    const SizedBox(height: 3),
                    valueWidget ?? Text(value ?? '', style: AppType.bodyStrong),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(hint!, style: AppType.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last)
          const Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
      ],
    );
  }
}
