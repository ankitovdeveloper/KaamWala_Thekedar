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
import '../shell/home_shell.dart';

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
                  const KwSectionTitle('Meri Activity'),
                  KwMenuCard(
                    children: [
                      KwMenuRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Active Bookings',
                        subtitle: bundle.stats.activeBookings == 0
                            ? 'Abhi koi booking nahi'
                            : '${bundle.stats.activeBookings} bookings chal rahi hain',
                        trailing: bundle.stats.activeBookings == 0
                            ? null
                            : KwBadge(label: '${bundle.stats.activeBookings}'),
                        onTap: () => HomeShell.of(context)?.goToTab(1),
                      ),
                      KwMenuRow(
                        icon: Icons.favorite_border_rounded,
                        label: 'Saved Labour',
                        subtitle: '${bundle.stats.savedLabours} log saved hain',
                        onTap: () => _toast('Saved list jald aayegi'),
                      ),
                      KwMenuRow(
                        icon: Icons.star_outline_rounded,
                        label: 'Meri Reviews',
                        subtitle:
                            '${bundle.stats.reviewsGiven} reviews diye hain',
                        divider: false,
                        onTap: () => _toast('Reviews page jald aayega'),
                      ),
                    ],
                  ),
                  const KwSectionTitle('Address'),
                  KwMenuCard(
                    children: [
                      for (final address in bundle.addresses)
                        KwMenuRow(
                          icon: address.icon,
                          label: address.label,
                          subtitle: address.line,
                          trailing: address.isDefault
                              ? const KwBadge(label: 'Default')
                              : null,
                          onTap: () => _toast('${address.label} edit karein'),
                        ),
                      KwMenuRow(
                        icon: Icons.add_rounded,
                        label: 'Naya address add karein',
                        showChevron: false,
                        divider: false,
                        onTap: () => _toast('Address add jald aayega'),
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
                KwIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Profile share karein',
                  onPressed: () => _toast(
                    user.referralCode == null
                        ? 'Referral code jald aayega'
                        : 'Referral code: ${user.referralCode}',
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
              child: KwButton(
                label: 'Profile Edit karein',
                icon: Icons.edit_outlined,
                variant: KwButtonVariant.ghost,
                size: KwButtonSize.small,
                expand: false,
                onPressed: () => _toast('Profile edit jald aayega'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(ThekedarStats stats) {
    // IntrinsicHeight lets the three boxes match the tallest one. Without it,
    // CrossAxisAlignment.stretch has no height to stretch to inside a sliver.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatBox(
              value: stats.totalBookings,
              label: 'Total Bookings',
              delay: const Duration(milliseconds: 220),
            ),
          ),
          Gap.hLg,
          Expanded(
            child: _StatBox(
              value: stats.totalSpend,
              label: 'Total Spend',
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
              label: 'Reviews Diye',
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
