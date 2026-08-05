import 'package:flutter/material.dart';

import '../../core/animations/effects.dart';
import '../../core/animations/entrance.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';
import '../location/location_picker_screen.dart';
import '../shell/home_shell.dart';
import 'edit_profile_screen.dart';

/// Profile screen, backed by `GET /v1/thekedar/profile` — one call returns the
/// user, the dashboard stats and the saved addresses.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scroll = ScrollController();
  late final Loadable<ProfileBundle> _profile = Loadable(
    () => context.repo.profile(),
  );

  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (mounted) setState(() => _offset = _scroll.offset);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _profile.load();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _profile.dispose();
    super.dispose();
  }

  Future<void> _editProfile(AppUser user) async {
    final updated = await EditProfileScreen.push(context, user);
    if (updated == null || !mounted) return;
    // The form already wrote through to the session; refresh the bundle so
    // the hero and the address list match what was just saved.
    _profile.load(silent: true);
  }

  Future<void> _editAddress() async {
    final saved = await LocationPickerScreen.push(context);
    if (saved != true || !mounted) return;
    _profile.load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: ListenableBuilder(
        listenable: _profile,
        builder: (context, _) {
          final bundle = _profile.value;

          if (bundle == null) {
            return Column(
              children: [
                // Keep the yellow band so the status bar doesn't flash white.
                const KwHeader(
                  child: SizedBox(height: 60, width: double.infinity),
                ),
                Expanded(
                  child: _profile.error != null
                      ? ApiErrorState(
                          error: _profile.error!,
                          onRetry: () => _profile.load(),
                        )
                      : const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.6),
                          ),
                        ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () => _profile.load(silent: true),
            color: AppColors.black,
            backgroundColor: AppColors.yellow,
            child: _content(bundle),
          );
        },
      ),
    );
  }

  Widget _content(ProfileBundle bundle) {
    final s = context.s;
    // Same parallax treatment as the labour detail hero.
    final parallax = (_offset * 0.45).clamp(0.0, 200.0);
    final fade = (1 - _offset / 170).clamp(0.0, 1.0);

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
              child: Opacity(opacity: fade, child: _hero(bundle.user)),
            ),
          ),
        ),
        SliverContentWidth(
          sliver: SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              Gap.x3l,
              context.pagePadding,
              Gap.x7l,
            ),
            sliver: SliverList.list(
              children: Stagger.wrap(
                base: const Duration(milliseconds: 120),
                offset: 20,
                children: [
                  _statsRow(bundle.stats),
                  Gap.vXxl,
                  KwSectionTitle(s.myActivity),
                  KwMenuCard(
                    children: [
                      KwMenuRow(
                        icon: Icons.calendar_month_outlined,
                        label: s.activeBookings,
                        subtitle: bundle.stats.activeBookings == 0
                            ? s.noBookingsYet
                            : s.bookingsRunning(bundle.stats.activeBookings),
                        trailing: bundle.stats.activeBookings == 0
                            ? null
                            : KwBadge(label: '${bundle.stats.activeBookings}'),
                        onTap: () => HomeShell.of(context)?.goToTab(1),
                      ),
                      KwMenuRow(
                        icon: Icons.favorite_border_rounded,
                        label: s.savedLabour,
                        subtitle: s.savedLabourCount(bundle.stats.savedLabours),
                        onTap: () => _toast(s.savedListSoon),
                      ),
                      KwMenuRow(
                        icon: Icons.star_outline_rounded,
                        label: s.myReviews,
                        subtitle: s.reviewsGivenCount(
                          bundle.stats.reviewsGiven,
                        ),
                        divider: false,
                        onTap: () => _toast(s.reviewsPageSoon),
                      ),
                    ],
                  ),
                  KwSectionTitle(s.addressSection),
                  KwMenuCard(
                    children: [
                      // The user's own coordinates come first: this is the row
                      // that decides where Search looks, so it is the one they
                      // are most likely to be after.
                      KwMenuRow(
                        icon: Icons.my_location_rounded,
                        label: s.locationTitle,
                        subtitle:
                            bundle.user.address ??
                            bundle.user.city ??
                            s.setLocation,
                        onTap: _editAddress,
                      ),
                      for (final address in bundle.addresses)
                        KwMenuRow(
                          icon: address.icon,
                          label: address.label,
                          subtitle: address.line,
                          trailing: address.isDefault
                              ? KwBadge(label: s.defaultBadge)
                              : null,
                          onTap: _editAddress,
                        ),
                      KwMenuRow(
                        icon: Icons.add_rounded,
                        label: s.addNewAddress,
                        showChevron: false,
                        divider: false,
                        onTap: () => _toast(s.addressAddSoon),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(AppUser user) {
    final s = context.s;
    return Container(
      width: double.infinity,
      color: AppColors.yellow,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Gap.vLg,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Pencil in the top-right is where people look for "edit" on a
                // profile header, so it sits alongside share as well as on the
                // labelled button under the phone number.
                KwIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: s.editProfile,
                  onPressed: () => _editProfile(user),
                ),
                Gap.hLg,
                KwIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: s.shareProfile,
                  onPressed: () => _toast(
                    user.referralCode == null
                        ? s.referralCodeSoon
                        : s.referralCodeIs(user.referralCode!),
                  ),
                ),
              ],
            ),
            Gap.vXl,
            FadeSlideIn(
              from: SlideFrom.none,
              beginScale: 0.7,
              duration: const Duration(milliseconds: 620),
              child: KwAvatar(
                initials: user.initials,
                size: 76,
                background: AppColors.black,
                foreground: AppColors.yellow,
                ring: AppColors.veil06,
              ),
            ),
            Gap.vXl,
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              offset: 10,
              child: Text(user.name, style: AppType.h2),
            ),
            const SizedBox(height: 3),
            FadeSlideIn(
              delay: const Duration(milliseconds: 130),
              offset: 10,
              child: Text(
                user.fullPhone,
                style: AppType.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
            Gap.vXl,
            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              offset: 10,
              // Outline, not ghost: a 6% veil on the yellow hero is all but
              // invisible, and the pencil icon that labels this row has to
              // read at a glance.
              child: KwButton(
                label: s.editProfile,
                icon: Icons.edit_outlined,
                variant: KwButtonVariant.outline,
                size: KwButtonSize.small,
                expand: false,
                onPressed: () => _editProfile(user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(ThekedarStats stats) {
    final s = context.s;
    // IntrinsicHeight lets the three boxes match the tallest one. Without it,
    // CrossAxisAlignment.stretch has no height to stretch to inside a sliver.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatBox(
              value: stats.totalBookings,
              label: s.statTotalBookings,
              delay: const Duration(milliseconds: 220),
            ),
          ),
          Gap.hLg,
          Expanded(
            child: _StatBox(
              value: stats.totalSpend,
              label: s.statTotalSpend,
              prefix: '₹',
              grouped: true,
              highlight: true,
              delay: const Duration(milliseconds: 300),
            ),
          ),
          Gap.hLg,
          Expanded(
            child: _StatBox(
              value: stats.reviewsGiven,
              label: s.statReviewsGiven,
              delay: const Duration(milliseconds: 380),
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.delay,
    this.prefix = '',
    this.grouped = false,
    this.highlight = false,
  });

  final int value;
  final String label;
  final Duration delay;
  final String prefix;
  final bool grouped;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return KwCard(
      radius: Radii.rSm,
      color: highlight ? AppColors.yellow : AppColors.white,
      borderColor: highlight ? AppColors.yellow : AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CountUp(
              value: value,
              prefix: prefix,
              groupThousands: grouped,
              delay: delay,
              style: AppType.statNumber,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppType.nano.copyWith(
              fontSize: 10,
              color: AppColors.muted,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
