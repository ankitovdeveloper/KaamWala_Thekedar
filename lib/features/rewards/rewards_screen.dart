import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/animations/pressable.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart' show Motion;
import '../../data/models/reward_models.dart';
import '../../data/session.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_celebration.dart';
import '../shell/home_shell.dart';
import 'claim_reward_sheet.dart';

/// Rewards — Share & Earn and Successful Match, laid out as the client's
/// design: a hero banner, one card per campaign with its levels on a horizontal
/// track, a "How It Works?" strip, and Share / Copy Link pinned at the bottom.
///
/// Nothing about a campaign is hard-coded here: titles, targets, reward names
/// and images, steps and tips all arrive in `GET /rewards`, so the admin can run
/// a new campaign without an app release. The screen only decides how a level
/// *looks* (✓ / reward image / claim / processing / rejected) from its status.
///
/// The same screen the Labour app has — the server hands a Thekedar their own
/// campaigns (their own targets and rewards), so only the wording around "find
/// work" turns into "find labour".
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, this.onFindLabour});

  /// What the Successful Match button does when there is no referral to share.
  /// [push] points it at the Search tab; left null the button just closes the
  /// screen.
  final VoidCallback? onFindLabour;

  /// Opens the screen from anywhere under the home shell.
  ///
  /// The shell is looked up here, while [context] is still beneath it: once the
  /// screen is pushed it sits on top of the shell, not inside it, and could no
  /// longer find the tab bar it has to send the Thekedar back to.
  static Future<void> push(BuildContext context) {
    final shell = HomeShell.of(context);
    final navigator = Navigator.of(context);
    return navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RewardsScreen(
          onFindLabour: () {
            navigator.popUntil((route) => route.isFirst);
            shell?.goToTab(0);
          },
        ),
      ),
    );
  }

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  static const _heroHeight = 262.0;

  RewardsData _data = RewardsData.empty;

  /// Earned rewards by id — the reject reason and tracking number live here,
  /// not in the campaign payload.
  Map<int, UserReward> _earned = const {};
  bool _loaded = false;
  bool _loading = true;
  bool _failed = false;

  final _howKey = GlobalKey();

  AppStrings get s => context.s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    final repo = context.repo;
    // History is garnish: a failure there must not take the screen down.
    final earnedFuture = repo.earnedRewards().then<Map<int, UserReward>>(
      (m) => m,
      onError: (_) => <int, UserReward>{},
    );
    try {
      final data = await repo.rewards();
      final earned = await earnedFuture;
      if (!mounted) return;
      setState(() {
        _data = data;
        _earned = earned;
        _loaded = true;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A pull-to-refresh that fails keeps what is already on screen.
      if (!_loaded) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The campaign whose referral the Share / Copy Link buttons hand out.
  ReferralInfo? get _referral {
    for (final c in _data.campaigns) {
      final r = c.referral;
      if (c.isSharing && r != null && r.code.isNotEmpty) return r;
    }
    return null;
  }

  /// An admin-uploaded banner, if there is one, replaces the built-in hero.
  String get _banner {
    for (final c in _data.campaigns) {
      if (c.bannerUrl.isNotEmpty) return c.bannerUrl;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cta = _loaded && _data.campaigns.isNotEmpty ? _cta() : null;
    // The app's theme paints the status bar yellow; this screen's is blue, so
    // it says so itself. The navigation bar follows the pinned white CTA.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _Rw.overlay,
      child: Scaffold(
        backgroundColor: _Rw.page,
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _Rw.heroPurple,
                edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
                onRefresh: () => _load(silent: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [_appBar(), ..._bodySlivers()],
                ),
              ),
            ),
            ?cta,
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- app bar

  Widget _appBar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: _Rw.heroBlue,
      surfaceTintColor: Colors.transparent,
      expandedHeight: _heroHeight,
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _RoundButton(
            fill: _Rw.navy.withValues(alpha: .92),
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
          ),
        ),
      ),
      actions: [
        if (_data.walletBalance > 0) _walletChip(_data.walletBalance),
        const SizedBox(width: 8),
        Center(
          child: _RoundButton(
            fill: _Rw.navy.withValues(alpha: .35),
            border: Colors.white,
            onTap: _scrollToHow,
            child: const Text('?',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
      ],
      systemOverlayStyle: _Rw.overlay,
      flexibleSpace: _HeroSpace(
        expandedHeight: _heroHeight,
        bannerUrl: _banner,
        collapsedTitle: s.rewardsTitle,
      ),
    );
  }

  Widget _walletChip(int balance) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text('₹$balance',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  void _scrollToHow() {
    final ctx = _howKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: Motion.slow, curve: Motion.enter, alignment: .12);
  }

  // ------------------------------------------------------------------ body

  List<Widget> _bodySlivers() {
    if (_loading && !_loaded) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
              child: CircularProgressIndicator(color: _Rw.heroPurple)),
        ),
      ];
    }
    if (_failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _message(Icons.cloud_off_outlined, s.rewardsLoadFail,
              action: TextButton(
                  onPressed: _load, child: Text(s.retry))),
        ),
      ];
    }
    final campaigns = _data.campaigns;
    if (campaigns.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _message(Icons.card_giftcard_outlined, s.rewardsEmpty,
              hint: s.rewardsEmptyHint),
        ),
      ];
    }

    final steps = _mergedSteps(campaigns);
    final tips = _mergedTips(campaigns);
    return [
      SliverContentWidth(
        sliver: SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
          // One box, not a lazy list: there are only a handful of cards, and
          // the "?" button scrolls to the How It Works card, which has to exist
          // already to be found.
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < campaigns.length; i++) ...[
                  _CampaignCard(
                    index: i,
                    campaign: campaigns[i],
                    earned: _earned,
                    onClaim: _claim,
                    onOpen: _openLevel,
                    onCopyCode: (code) => _copy(code, s.rewardsCodeCopied),
                  ),
                  const SizedBox(height: 14),
                ],
                if (steps.isNotEmpty || tips.isNotEmpty)
                  _HowItWorks(key: _howKey, steps: steps, tips: tips),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// The strip shows one flow for the whole screen, so steps are pooled across
  /// campaigns. A step every campaign has ("Earn Rewards") is the finish line
  /// and goes last, once.
  List<RewardStep> _mergedSteps(List<RewardCampaign> campaigns) {
    if (campaigns.length == 1) return campaigns.first.steps;
    String key(RewardStep s) => s.title.trim().toLowerCase();
    final counts = <String, int>{};
    for (final c in campaigns) {
      for (final k in c.steps.map(key).toSet()) {
        counts[k] = (counts[k] ?? 0) + 1;
      }
    }
    final seen = <String>{};
    final own = <RewardStep>[];
    final common = <RewardStep>[];
    for (final c in campaigns) {
      for (final s in c.steps) {
        if (!seen.add(key(s))) continue;
        (counts[key(s)]! > 1 ? common : own).add(s);
      }
    }
    return [...own, ...common];
  }

  List<String> _mergedTips(List<RewardCampaign> campaigns) {
    final seen = <String>{};
    return [
      for (final c in campaigns)
        for (final t in c.tips)
          if (seen.add(t.toLowerCase())) t,
    ];
  }

  // ---------------------------------------------------------------- claim

  Future<void> _claim(RewardLevel level) async {
    final id = level.userRewardId;
    if (id == null) return;
    final name =
        level.rewardName.isNotEmpty ? level.rewardName : s.rewardsTitle;
    final done = await ClaimRewardSheet.show(context,
        userRewardId: id, rewardName: name);
    if (!done || !mounted) return;
    // Refresh behind the popup so the level already reads "Processing" when it
    // closes.
    final reload = _load(silent: true);
    await KwCelebration.show(
      context,
      title: s.claimDoneTitle,
      message: s.claimDoneMsg,
    );
    await reload;
  }

  void _openLevel(RewardLevel level, _Theme theme, String unit) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // The sheet draws its own handle; the app theme's would be a second one.
      showDragHandle: false,
      builder: (ctx) => _LevelSheet(
        level: level,
        earned: _earned[level.userRewardId],
        theme: theme,
        unit: unit,
        onClaim: () {
          Navigator.pop(ctx);
          _claim(level);
        },
      ),
    );
  }

  // ------------------------------------------------------------------ CTA

  /// Share + Copy Link when there is a referral to hand out. A Thekedar with
  /// only a match campaign has nothing to share, so the one useful action left
  /// is going to find labour.
  Widget? _cta() {
    final ref = _referral;
    final Widget content;
    if (ref != null) {
      final sharing = _data.campaigns.firstWhere((c) => c.isSharing);
      content = Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: () => _share(ref),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_Rw.shareA, _Rw.shareB],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _Rw.shareB.withValues(alpha: .35),
                        blurRadius: 14,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.share, size: 22, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          sharing.buttonText.isNotEmpty
                              ? sharing.buttonText
                              : s.rewardsShareBtn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 24, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: () => _copy(ref.link, s.rewardsLinkCopied),
            child: Container(
              width: 88,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _Rw.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copy_rounded,
                      size: 20, color: AppColors.black),
                  const SizedBox(height: 2),
                  Text(s.rewardsCopyLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black)),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      final match = _data.campaigns.first;
      content = KwButton(
        label: match.buttonText.isNotEmpty
            ? match.buttonText
            : s.rewardsFindLabourBtn,
        icon: Icons.search_rounded,
        onPressed: _findLabour,
      );
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: _Rw.shareB.withValues(alpha: .10),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
              padding: const EdgeInsets.only(bottom: 12), child: content),
        ),
      ),
    );
  }

  Future<void> _share(ReferralInfo ref) async {
    final text = s.rewardsShareText(ref.code, ref.link);
    final copied = s.rewardsLinkCopied;
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // No share sheet on this device — the link is still worth having.
      await _copy(ref.link, copied);
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Back out to the shell and land on Search, where the labour is.
  void _findLabour() {
    final go = widget.onFindLabour;
    if (go != null) {
      go();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _message(IconData icon, String text, {String? hint, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
            if (action != null) ...[const SizedBox(height: 8), action],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ palette

/// The Rewards screen's own colours. It follows the client's design — a blue →
/// purple hero, a purple card for Share & Earn, a green one for Successful
/// Match — rather than the app's green/grey dual tone.
class _Rw {
  _Rw._();

  static const heroBlue = Color(0xFF3556E6);
  static const heroPurple = Color(0xFF7B3FE0);
  static const navy = Color(0xFF1B2A6B);
  static const page = Color(0xFFF5F4FB);
  static const line = Color(0xFFE3E0EE);
  static const trackBg = Color(0xFFE2DFEC);
  static const idleNode = Color(0xFFDCD9E8);
  static const idleHalo = Color(0xFFEFEDF6);
  static const idleIcon = Color(0xFF9A95B0);
  static const goldRing = Color(0xFFF2B33D);
  static const goldChipBg = Color(0xFFFFD866);
  static const goldChipFg = Color(0xFF7A4B00);
  static const stepsBg = Color(0xFFE3EFFF);
  static const shareA = Color(0xFF8B5CF6);
  static const shareB = Color(0xFF6A38D8);
  static const stepColors = [
    Color(0xFFF0508C),
    Color(0xFF3B82F6),
    Color(0xFFFF7A2F),
    Color(0xFF9B6BEF),
  ];

  /// Light status-bar icons over the blue hero, dark navigation-bar icons over
  /// the white CTA bar. The app's own theme would paint the status bar yellow.
  static const overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}

/// A reward picture from the server, or null when there is none — the caller
/// then draws its own placeholder.
ImageProvider? _imageOf(String url) =>
    url.trim().isEmpty ? null : NetworkImage(url.trim());

/// One campaign's colours: the accent of its card, ribbon and track, plus the
/// ring / chip pair of its first reward (later rewards are gold, as designed).
class _Theme {
  final Color main;
  final Color halo;
  final Color ribbonBg;
  final Color ribbonFg;
  final Color ring;
  final Color chipBg;
  final Color chipFg;
  final IconData icon;

  const _Theme({
    required this.main,
    required this.halo,
    required this.ribbonBg,
    required this.ribbonFg,
    required this.ring,
    required this.chipBg,
    required this.chipFg,
    required this.icon,
  });

  static const sharing = _Theme(
    main: Color(0xFF7B4DDE),
    halo: Color(0xFFE4DAF8),
    ribbonBg: Color(0xFFFFC4DA),
    ribbonFg: Color(0xFFD81B60),
    ring: Color(0xFFEC5FA0),
    chipBg: Color(0xFFFF9EC5),
    chipFg: Color(0xFF9C1450),
    icon: Icons.campaign,
  );

  static const match = _Theme(
    main: Color(0xFF1FB26B),
    halo: Color(0xFFD2F2E1),
    ribbonBg: Color(0xFFFFD866),
    ribbonFg: Color(0xFF8A5A00),
    ring: Color(0xFF1FB26B),
    chipBg: Color(0xFFA8E8C8),
    chipFg: Color(0xFF0B6B3E),
    icon: Icons.handshake_outlined,
  );

  static _Theme of(RewardCampaign c) => c.isSharing ? sharing : match;
}

class _Accent {
  final Color ring;
  final Color chipBg;
  final Color chipFg;
  const _Accent(this.ring, this.chipBg, this.chipFg);

  static const gold = _Accent(_Rw.goldRing, _Rw.goldChipBg, _Rw.goldChipFg);
}

// --------------------------------------------------------------------- hero

class _RoundButton extends StatelessWidget {
  final Widget child;
  final Color fill;
  final Color? border;
  final VoidCallback onTap;

  const _RoundButton(
      {required this.child,
      required this.fill,
      required this.onTap,
      this.border});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: .88,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border!, width: 2),
        ),
        child: child,
      ),
    );
  }
}

/// The blue → purple banner behind the app bar. Fades out as the page scrolls
/// and leaves the plain bar (with "Rewards" in it) pinned.
class _HeroSpace extends StatelessWidget {
  final double expandedHeight;
  final String bannerUrl;
  final String collapsedTitle;

  const _HeroSpace({
    required this.expandedHeight,
    required this.bannerUrl,
    required this.collapsedTitle,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(
      builder: (context, c) {
        final min = top + kToolbarHeight;
        final max = top + expandedHeight;
        final t =
            max <= min ? 0.0 : ((c.maxHeight - min) / (max - min)).clamp(0.0, 1.0);
        final banner = _imageOf(bannerUrl);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_Rw.heroBlue, _Rw.heroPurple],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: max,
                // Squared so the artwork is gone well before the pinned bar's
                // own title fades in — no ghost of the big title behind it.
                child: Opacity(
                  opacity: t * t,
                  child: banner != null
                      ? Image(
                          image: banner,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _artwork(top),
                        )
                      : _artwork(top),
                ),
              ),
              Positioned(
                left: 64,
                right: 120,
                top: top,
                height: kToolbarHeight,
                child: Opacity(
                  opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(collapsedTitle,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
              ),
              // The top edge of the page sheet, so the hero reads as sitting
              // behind it.
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: 24,
                child: Opacity(
                  opacity: t * t,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: _Rw.page,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Built-in hero: title + tagline on the left, a phone with a handshake on
  /// the right. A designer's illustration can replace it through the campaign's
  /// banner image.
  Widget _artwork(double top) {
    return LayoutBuilder(
      builder: (context, c) {
        final s = context.s;
        final w = c.maxWidth;
        final textW = w * .56;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ..._confetti(w, top),
            Positioned(
              left: 18,
              top: top + 58,
              width: textW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            fontSize: 31,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            color: Colors.white),
                        children: [
                          TextSpan(text: '${s.rewardsHeroTop} '),
                          TextSpan(
                              text: s.rewardsHeroAccent,
                              style:
                                  const TextStyle(color: Color(0xFFFFD43B))),
                          TextSpan(text: '\n${s.rewardsHeroBottom} 🎁'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(s.rewardsHeroSub,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ],
              ),
            ),
            Positioned(
              right: 26,
              top: top + 54,
              child: Transform.rotate(angle: .06, child: _phone()),
            ),
            Positioned(
              right: 10,
              bottom: 34,
              width: math.min(190, w * .5),
              child: Transform.rotate(
                angle: -.09,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD43B),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Text(s.rewardsTagline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: _Rw.navy)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _phone() {
    return Container(
      width: 92,
      height: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Rw.navy, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .25),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.handshake_rounded, size: 46, color: _Rw.navy),
          const SizedBox(height: 8),
          for (final w in const [58.0, 44.0])
            Container(
              width: w,
              height: 6,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: _Rw.idleHalo,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _confetti(double w, double top) {
    Widget bit(double x, double y, Color c, double a, {double s = 9}) =>
        Positioned(
          left: x * w,
          top: top + y,
          child: Transform.rotate(
            angle: a,
            child: Container(width: s, height: s * .55, color: c),
          ),
        );
    return [
      bit(.50, 52, const Color(0xFFFF5CA8), .6),
      bit(.92, 66, const Color(0xFFFFD43B), -.5, s: 12),
      bit(.62, 40, const Color(0xFF5CE1E6), .9, s: 8),
      bit(.84, 150, const Color(0xFFFF5CA8), -.8, s: 8),
      bit(.62, 128, const Color(0xFFFFD43B), .4),
    ];
  }
}

// ----------------------------------------------------------- campaign card

class _CampaignCard extends StatelessWidget {
  final int index;
  final RewardCampaign campaign;
  final Map<int, UserReward> earned;
  final ValueChanged<RewardLevel> onClaim;
  final void Function(RewardLevel level, _Theme theme, String unit) onOpen;
  final ValueChanged<String> onCopyCode;

  const _CampaignCard({
    required this.index,
    required this.campaign,
    required this.earned,
    required this.onClaim,
    required this.onOpen,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = campaign;
    final theme = _Theme.of(c);
    final unit = c.isSharing ? s.rewardsUnitSharing : s.rewardsUnitMatch;
    final unitOne =
        c.isSharing ? s.rewardsUnitSharingOne : s.rewardsUnitMatchOne;
    final ribbon =
        c.isSharing ? s.rewardsRibbonSharing : s.rewardsRibbonMatch;
    final ref = c.referral;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.main.withValues(alpha: .22), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: theme.main.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _chip(s, theme),
                    const SizedBox(height: 8),
                    Text(c.title,
                        style: const TextStyle(
                            fontSize: 18,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black)),
                    if (c.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(c.subtitle,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors.muted)),
                    ],
                    if (c.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(c.description,
                          style: const TextStyle(
                              fontSize: 12, height: 1.35, color: AppColors.black)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Transform.rotate(
                  angle: -.07,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 112),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.ribbonBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(ribbon,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: theme.ribbonFg)),
                  ),
                ),
              ),
            ],
          ),
          if (c.levels.isNotEmpty) ...[
            const SizedBox(height: 16),
            _LevelTrack(
              levels: c.levels,
              current: c.current,
              theme: theme,
              unit: unit,
              unitOne: unitOne,
              earned: earned,
              onClaim: onClaim,
              onOpen: onOpen,
            ),
          ],
          if (c.target > 0) ...[
            const SizedBox(height: 14),
            _progressCaption(s, c, theme, unit),
          ],
          if (c.isSharing && ref != null && ref.code.isNotEmpty) ...[
            const SizedBox(height: 12),
            _codeRow(s, ref.code, theme),
          ],
        ],
      ),
    );
  }

  Widget _chip(AppStrings s, _Theme theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 13, 5),
      decoration: BoxDecoration(
        color: theme.main,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(s.rewardsCampaignN(index + 1),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  /// "20 / 50 Shares" and how far the next reward is — the numbers behind the
  /// track, which is only a picture of them.
  Widget _progressCaption(
      AppStrings s, RewardCampaign c, _Theme theme, String unit) {
    final next = c.nextTarget == null
        ? s.rewardsAllDone
        : s.rewardsToNext(c.remainingToNext);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
            children: [
              TextSpan(
                  text: '${c.current}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: theme.main)),
              TextSpan(text: ' / ${c.target} $unit'),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(next,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.black)),
      ],
    );
  }

  Widget _codeRow(AppStrings s, String code, _Theme theme) {
    return Pressable(
      onTap: () => onCopyCode(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.main.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(s.rewardsYourCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            Text(code,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: theme.main)),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 16, color: theme.main),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- level track

/// The levels of one campaign along a horizontal line: a tick for every
/// milestone reached, a ringed picture for every reward. The line is filled up
/// to wherever the worker's count has got to, so it doubles as the progress bar.
///
/// Columns share the card's width in proportion (rewards are wider); a campaign
/// with too many levels to fit scrolls sideways instead of squeezing them.
class _LevelTrack extends StatelessWidget {
  final List<RewardLevel> levels;
  final int current;
  final _Theme theme;
  final String unit;
  final String unitOne;
  final Map<int, UserReward> earned;
  final ValueChanged<RewardLevel> onClaim;
  final void Function(RewardLevel level, _Theme theme, String unit) onOpen;

  const _LevelTrack({
    required this.levels,
    required this.current,
    required this.theme,
    required this.unit,
    required this.unitOne,
    required this.earned,
    required this.onClaim,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final avail = c.maxWidth;
        double weight(RewardLevel l) => l.isMilestone ? 1.0 : 1.7;
        double minWidth(RewardLevel l) => l.isMilestone ? 40.0 : 70.0;
        final totalWeight = levels.fold<double>(0, (s, l) => s + weight(l));
        final widths = [
          for (final l in levels)
            math.max(minWidth(l), avail * weight(l) / totalWeight),
        ];
        final total = widths.fold<double>(0, (a, b) => a + b);

        // The nodes are drawn for a full-size column (46 / 80); on a narrow
        // phone the columns are tighter, so the nodes shrink to stay clear of
        // their neighbours instead of overlapping them.
        var scale = 1.0;
        for (var i = 0; i < levels.length; i++) {
          scale = math.min(
              scale, widths[i] / (levels[i].isMilestone ? 46.0 : 80.0));
        }
        scale = scale.clamp(.75, 1.0);

        // How much of each half-column of line is filled. The stretch between
        // two nodes is the right half of one column plus the left half of the
        // next, and the worker's count decides how far along it they are.
        final n = levels.length;
        final leftFill = List<double>.filled(n, 0);
        final rightFill = List<double>.filled(n, 0);
        for (var i = 0; i < n - 1; i++) {
          final a = levels[i].target;
          final b = levels[i + 1].target;
          final p = current >= b
              ? 1.0
              : current <= a || b <= a
                  ? 0.0
                  : (current - a) / (b - a);
          final half = widths[i] / 2;
          final filled = p * (half + widths[i + 1] / 2);
          rightFill[i] = (filled / half).clamp(0.0, 1.0);
          leftFill[i + 1] = ((filled - half) / (widths[i + 1] / 2)).clamp(0.0, 1.0);
        }

        var rewardIndex = 0;
        final columns = <Widget>[];
        for (var i = 0; i < n; i++) {
          final level = levels[i];
          _Accent? accent;
          if (!level.isMilestone) {
            // The first reward wears the campaign's colour, the rest are gold.
            accent = rewardIndex == 0
                ? _Accent(theme.ring, theme.chipBg, theme.chipFg)
                : _Accent.gold;
            rewardIndex++;
          }
          final u = level.target == 1 ? unitOne : unit;
          columns.add(_LevelColumn(
            width: widths[i],
            scale: scale,
            // The last level is the grand prize and is drawn the largest.
            grand: i == n - 1 && !level.isMilestone,
            level: level,
            reached: current >= level.target,
            theme: theme,
            accent: accent,
            leftFill: i == 0 ? null : leftFill[i],
            rightFill: i == n - 1 ? null : rightFill[i],
            unit: u,
            earned: earned[level.userRewardId],
            onClaim: () => onClaim(level),
            onOpen: () => onOpen(level, theme, u),
          ));
        }

        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columns,
        );
        return total <= avail + .5
            ? row
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: row);
      },
    );
  }
}

class _LevelColumn extends StatelessWidget {
  /// Thickness of the track line, and the height of the band every node is
  /// centred in (tall enough for the grand prize) — so the line passes through
  /// the middle of milestones and rewards alike, as in the design.
  static const _lineH = 6.0;
  static const _band = 80.0;

  final double width;

  /// 1 at full size; below that the node (not the labels) is drawn smaller.
  final double scale;
  final bool grand;
  final RewardLevel level;
  final bool reached;
  final _Theme theme;
  final _Accent? accent;
  final double? leftFill;
  final double? rightFill;
  final String unit;
  final UserReward? earned;
  final VoidCallback onClaim;
  final VoidCallback onOpen;

  const _LevelColumn({
    required this.width,
    required this.scale,
    required this.grand,
    required this.level,
    required this.reached,
    required this.theme,
    required this.accent,
    required this.leftFill,
    required this.rightFill,
    required this.unit,
    required this.earned,
    required this.onClaim,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final phase = level.phase;
    final band = _band * scale;
    final nodeSize = _nodeSize * scale;
    // Each label hangs from its own node (a reward's sits lower than a
    // milestone's, as in the design), while every node is centred on the line.
    final gap = (band - nodeSize) / 2;
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          if (leftFill != null)
            Positioned(
              left: 0,
              width: width / 2,
              top: (band - _lineH) / 2,
              child: _Segment(fill: leftFill!, color: theme.main),
            ),
          if (rightFill != null)
            Positioned(
              right: 0,
              width: width / 2,
              top: (band - _lineH) / 2,
              child: _Segment(fill: rightFill!, color: theme.main),
            ),
          Column(
            children: [
              SizedBox(height: gap),
              level.isMilestone ? _milestone() : _reward(phase),
              const SizedBox(height: 6),
              Text('${level.target}',
                  style: const TextStyle(
                      fontSize: 21,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black)),
              Text(unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black)),
              if (!level.isMilestone) ...[
                const SizedBox(height: 8),
                _bottom(s, phase),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Diameter of this level's node at full size: small ticks for milestones,
  /// big rings for rewards, the biggest for the grand prize.
  double get _nodeSize => level.isMilestone ? 36.0 : (grand ? 72.0 : 62.0);

  Widget _milestone() {
    final size = _nodeSize * scale;
    final inner = 28.0 * scale;
    // A white tick on a solid disc, set in a pale halo. The tick is thickened
    // with hairline white shadows because the icon font only has the thin cut.
    const bold = [
      Shadow(color: Colors.white, offset: Offset(.7, 0)),
      Shadow(color: Colors.white, offset: Offset(-.7, 0)),
      Shadow(color: Colors.white, offset: Offset(0, .7)),
    ];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? theme.halo : _Rw.idleHalo,
      ),
      child: Container(
        width: inner,
        height: inner,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reached ? theme.main : _Rw.idleNode,
        ),
        child: Icon(reached ? Icons.check : Icons.lock_outline,
            size: (reached ? 19 : 15) * scale,
            color: reached ? Colors.white : _Rw.idleIcon,
            shadows: reached ? bold : null),
      ),
    );
  }

  Widget _reward(LevelPhase phase) {
    final a = accent!;
    final size = _nodeSize * scale;
    final image = _imageOf(level.imageUrl);
    final fallback = Container(
      color: a.chipBg.withValues(alpha: .35),
      alignment: Alignment.center,
      child: Icon(
          level.isWallet ? Icons.account_balance_wallet : Icons.card_giftcard,
          size: size * .42,
          color: a.chipFg),
    );
    final badge = switch (phase) {
      LevelPhase.delivered => (Icons.check, const Color(0xFF1FB26B)),
      LevelPhase.inReview => (Icons.hourglass_top, const Color(0xFFE09B1A)),
      LevelPhase.rejected => (Icons.close, const Color(0xFFD3453F)),
      _ => null,
    };
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: a.ring, width: grand ? 4 : 3),
              boxShadow: [
                BoxShadow(
                    color: a.ring.withValues(alpha: .30),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ClipOval(
              child: image == null
                  ? fallback
                  : Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: badge.$2,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(badge.$1, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Under a reward: what it is, or — once the worker has a stake in it — what
  /// state it is in. Claim is the one that is a button.
  Widget _bottom(AppStrings s, LevelPhase phase) {
    final a = accent!;
    Widget pill(String text, Color bg, Color fg) => _chipBox(text, bg, fg);
    switch (phase) {
      case LevelPhase.claimable:
        return Pressable(
          onTap: onClaim,
          child: Container(
            width: width - 8,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: theme.main,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: theme.main.withValues(alpha: .35),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Text(s.rewardsClaim,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        );
      case LevelPhase.inReview:
        return pill(s.rewardsStatusProcessing, const Color(0xFFFFE8B3),
            const Color(0xFF8A5A00));
      case LevelPhase.delivered:
        return pill(s.rewardsStatusDelivered, const Color(0xFFCFF0DD),
            const Color(0xFF0B6B3E));
      case LevelPhase.rejected:
        return pill(s.rewardsStatusRejected, const Color(0xFFFAE0DE),
            const Color(0xFFB3261E));
      case LevelPhase.locked:
      case LevelPhase.reached:
        return pill(_rewardCaption(s, level), a.chipBg, a.chipFg);
    }
  }

  Widget _chipBox(String text, Color bg, Color fg) => Container(
        width: width - 8,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        // U+2011 keeps "T‑Shirt" from breaking after the hyphen.
        child: Text(text.replaceAll('-', '‑'),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: fg)),
      );
}

/// What a reward is called on its chip: "Get Free T-Shirt" for a parcel, the
/// admin's own wording for a wallet credit.
String _rewardCaption(AppStrings s, RewardLevel level) {
  if (level.isWallet) {
    return level.rewardName.isNotEmpty
        ? level.rewardName
        : s.rewardsWalletCredit(level.rewardValue);
  }
  final name =
      level.rewardName.isNotEmpty ? level.rewardName : s.rewardsTitle;
  return s.rewardsGet(name);
}

/// A stretch of the track line, filled from the left up to [fill].
class _Segment extends StatelessWidget {
  final double fill;
  final Color color;
  const _Segment({required this.fill, required this.color});

  @override
  Widget build(BuildContext context) {
    // Square ends on purpose: two half-columns meet at every column boundary,
    // and rounded caps would pinch the line there.
    return Container(
      height: _LevelColumn._lineH,
      color: _Rw.trackBg,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fill.clamp(0.0, 1.0),
        child: ColoredBox(color: color),
      ),
    );
  }
}

// ------------------------------------------------------------ how it works

class _HowItWorks extends StatelessWidget {
  final List<RewardStep> steps;
  final List<String> tips;

  const _HowItWorks({super.key, required this.steps, required this.tips});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    // Up to four steps share the width, joined by arrows, as designed; more
    // than that would be unreadably narrow, so the strip scrolls instead.
    final scrolls = steps.length > 4;
    Widget step(int i) => _StepColumn(index: i, step: steps[i]);

    Widget strip;
    if (scrolls) {
      strip = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) _arrow(),
              SizedBox(width: 92, child: step(i)),
            ],
          ],
        ),
      );
    } else {
      strip = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) _arrow(),
            Expanded(child: step(i)),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Rw.stepsBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isNotEmpty) ...[
            Text(s.rewardsHow,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black)),
            const SizedBox(height: 12),
            strip,
          ],
          if (tips.isNotEmpty) ...[
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(color: _Rw.heroBlue.withValues(alpha: .15), height: 1),
              const SizedBox(height: 10),
            ] else ...[
              Text(s.rewardsTips,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black)),
              const SizedBox(height: 8),
            ],
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.lightbulb_outline,
                          size: 15, color: _Rw.heroBlue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tip,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.black)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _arrow() => const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Icon(Icons.arrow_forward, size: 16, color: AppColors.muted),
      );
}

class _StepColumn extends StatelessWidget {
  final int index;
  final RewardStep step;

  const _StepColumn({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final color = _Rw.stepColors[index % _Rw.stepColors.length];
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: .35),
                  blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Icon(_stepIcon(step.icon), size: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text('${index + 1}. ${step.title}',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: AppColors.black)),
        if (step.description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(step.description,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, height: 1.25, color: AppColors.muted)),
        ],
      ],
    );
  }

  /// The admin types the icon as free text ("share / users / gift / etc."), so
  /// anything unrecognised falls back to a star rather than a blank circle.
  static IconData _stepIcon(String key) {
    switch (key.trim().toLowerCase()) {
      case 'share':
        return Icons.share_outlined;
      case 'users':
      case 'user':
      case 'friends':
      case 'group':
        return Icons.group;
      case 'gift':
      case 'reward':
        return Icons.card_giftcard;
      case 'handshake':
      case 'match':
        return Icons.handshake_outlined;
      case 'check':
      case 'done':
        return Icons.check_circle_outline;
      case 'wallet':
      case 'money':
      case 'cash':
        return Icons.account_balance_wallet_outlined;
      case 'trophy':
      case 'award':
        return Icons.emoji_events_outlined;
      case 'phone':
      case 'mobile':
        return Icons.phone_android;
      default:
        return Icons.stars_outlined;
    }
  }
}

// ------------------------------------------------------------- level sheet

/// Tap a reward and this is its story: the picture, what it takes, where it
/// stands, and — for one the worker can claim — the button. It is also where
/// the tracking number and an admin's reason for a rejection are written out,
/// because there is no room for them under a narrow column.
class _LevelSheet extends StatelessWidget {
  final RewardLevel level;
  final UserReward? earned;
  final _Theme theme;
  final String unit;
  final VoidCallback onClaim;

  const _LevelSheet({
    required this.level,
    required this.earned,
    required this.theme,
    required this.unit,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final phase = level.phase;
    final image = _imageOf(level.imageUrl);
    final name = level.rewardName.isNotEmpty
        ? level.rewardName
        : (level.isWallet
            ? s.rewardsWalletCredit(level.rewardValue)
            : s.rewardsTitle);
    final notes = [
      if (level.isWallet &&
          phase == LevelPhase.delivered &&
          level.rewardValue > 0)
        s.rewardsWalletAdded(level.rewardValue),
      if ((earned?.trackingNumber ?? '').isNotEmpty)
        s.rewardsTracking(earned!.trackingNumber),
      if (phase == LevelPhase.rejected && (earned?.adminNote ?? '').isNotEmpty)
        s.rewardsReason(earned!.adminNote),
    ];
    final (String label, Color bg, Color fg) = switch (phase) {
      LevelPhase.locked => (
          s.rewardsStatusLocked,
          _Rw.idleHalo,
          AppColors.muted
        ),
      LevelPhase.reached => (
          s.rewardsStatusReached,
          const Color(0xFFCFF0DD),
          const Color(0xFF0B6B3E)
        ),
      LevelPhase.claimable => (
          s.rewardsClaim,
          theme.halo,
          theme.main
        ),
      LevelPhase.inReview => (
          s.rewardsStatusProcessing,
          const Color(0xFFFFE8B3),
          const Color(0xFF8A5A00)
        ),
      LevelPhase.delivered => (
          s.rewardsStatusDelivered,
          const Color(0xFFCFF0DD),
          const Color(0xFF0B6B3E)
        ),
      LevelPhase.rejected => (
          s.rewardsStatusRejected,
          const Color(0xFFFAE0DE),
          const Color(0xFFB3261E)
        ),
    };

    return Container(
      // A sheet shrink-wraps its content unless told otherwise; this one is
      // meant to span the screen.
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _Rw.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: theme.ring, width: 3),
                ),
                child: ClipOval(
                  child: image == null
                      ? Container(
                          color: theme.halo,
                          alignment: Alignment.center,
                          child: Icon(
                              level.isWallet
                                  ? Icons.account_balance_wallet
                                  : Icons.card_giftcard,
                              size: 40,
                              color: theme.main))
                      : Image(
                          image: image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
              const SizedBox(height: 14),
              Text(name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black)),
              const SizedBox(height: 4),
              Text(s.rewardsAtLevel(level.target, unit),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted)),
              if (level.rewardDescription.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(level.rewardDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.black)),
              ],
              const SizedBox(height: 14),
              if (phase != LevelPhase.claimable)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: fg)),
                ),
              for (final n in notes) ...[
                const SizedBox(height: 10),
                Text(n,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.black)),
              ],
              if (phase == LevelPhase.claimable) ...[
                const SizedBox(height: 4),
                _ThemedButton(
                  label: s.rewardsClaim,
                  icon: Icons.card_giftcard_rounded,
                  color: theme.main,
                  onTap: onClaim,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The claim button, in the campaign's own colour — [KwButton] only comes in
/// the app's yellow and black, and this sheet belongs to the campaign.
class _ThemedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ThemedButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: .35),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
