import 'package:flutter/material.dart';

import '../core/animations/effects.dart';
import '../core/animations/pressable.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/session.dart';

/// White rounded surface with the hairline border used across every screen.
class KwCard extends StatelessWidget {
  const KwCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.xxl),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.elevated = false,
    this.color = AppColors.white,
    this.borderColor = AppColors.border,
    this.radius = Radii.rMd,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool elevated;
  final Color color;
  final Color borderColor;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Padding(padding: margin, child: _surface(context, hovered: false));
    }
    return Padding(
      padding: margin,
      child: HoverLift(
        onTap: onTap,
        builder: (context, hovered) => _surface(context, hovered: hovered),
      ),
    );
  }

  Widget _surface(BuildContext context, {required bool hovered}) {
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.enter,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: hovered
            ? AppColors.cardShadowHover
            : elevated
            ? AppColors.cardShadow
            : null,
      ),
      child: child,
    );
  }
}

/// Monogram avatar, or the uploaded photo when there is one.
///
/// Colours are derived from the name so the same worker keeps the same identity
/// colour on every screen — and so the monogram still reads as *them* while a
/// photo is downloading or after it fails to.
class KwAvatar extends StatelessWidget {
  const KwAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 50,
    this.background,
    this.foreground,
    this.ring,
    this.online = false,
  });

  final String initials;

  /// `users.profile_photo_url` from the API. Null, or a URL that 404s, leaves
  /// the monogram in place rather than a broken-image box.
  final String? photoUrl;

  final double size;
  final Color? background;
  final Color? foreground;
  final Color? ring;

  /// Draws a small live dot at the corner.
  final bool online;

  /// An empty string means "no photo". `strOrNull` already collapses that for
  /// API payloads, but a caller building a URL by hand can still hand over ''.
  String? get _url {
    final url = photoUrl?.trim();
    return url == null || url.isEmpty ? null : url;
  }

  /// The photo, with the monogram standing in until it arrives and again if it
  /// never does — a dead URL must not leave a hole where the face goes.
  Widget _photo(String url, Widget monogram) => Image.network(
    url,
    width: size,
    height: size,
    fit: BoxFit.cover,
    // Keeps the old frame while a replacement uploads instead of blinking.
    gaplessPlayback: true,
    // Web only, and the reason avatars work there at all: uploads are served
    // straight off disk by the web server, outside the API's CORS handling, and
    // decoding a cross-origin image into a canvas without an
    // `Access-Control-Allow-Origin` header fails. An <img> element has no such
    // rule, so this falls back to one rather than to the monogram.
    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : monogram,
    errorBuilder: (context, _, _) => monogram,
  );

  @override
  Widget build(BuildContext context) {
    final pair = AppColors.avatarPair(initials);
    final bg = background ?? pair.$1;
    final fg = foreground ?? pair.$2;
    final url = _url;

    final monogram = FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: AppType.family,
            fontFamilyFallback: AppType.fallback,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );

    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: url == null ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 4),
      ),
      child: url == null ? monogram : _photo(url, monogram),
    );

    if (!online) return circle;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        circle,
        Positioned(
          right: 0,
          bottom: size * 0.04,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded tag used for skills.
class KwPill extends StatelessWidget {
  const KwPill({
    super.key,
    required this.label,
    this.background = AppColors.surfaceAlt,
    this.foreground = AppColors.black,
    this.dense = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Gap.lg : Gap.xl,
        vertical: dense ? 3 : Gap.xs,
      ),
      decoration: BoxDecoration(color: background, borderRadius: Radii.rPill),
      child: Text(
        label,
        style: (dense ? AppType.micro : AppType.label).copyWith(
          color: foreground,
          fontWeight: dense ? FontWeight.w400 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Booking status chip. Pending quietly pulses so it reads as "waiting on
/// someone else" rather than a settled state.
class KwStatusBadge extends StatelessWidget {
  const KwStatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final KwStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      KwStatusTone.confirmed => (
        AppColors.successBg,
        AppColors.successDark,
        Icons.check_rounded,
      ),
      KwStatusTone.pending => (
        AppColors.yellowLight,
        AppColors.pendingText,
        Icons.hourglass_empty_rounded,
      ),
      KwStatusTone.done => (
        AppColors.doneBg,
        AppColors.muted,
        Icons.check_rounded,
      ),
      KwStatusTone.cancelled => (
        const Color(0xFFFDECEC),
        AppColors.danger,
        Icons.close_rounded,
      ),
    };

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
      decoration: BoxDecoration(color: bg, borderRadius: Radii.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          Gap.hXs,
          Text(
            label,
            style: AppType.micro.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (tone != KwStatusTone.pending) return chip;
    return _BreathingOpacity(child: chip);
  }
}

enum KwStatusTone { confirmed, pending, done, cancelled }

class _BreathingOpacity extends StatefulWidget {
  const _BreathingOpacity({required this.child});
  final Widget child;

  @override
  State<_BreathingOpacity> createState() => _BreathingOpacityState();
}

class _BreathingOpacityState extends State<_BreathingOpacity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncDecorativeTicker(this, _c, reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: Tween(
        begin: 1.0,
        end: 0.55,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Star row. Stars pop in one by one the first time they appear.
class KwStars extends StatelessWidget {
  const KwStars({
    super.key,
    required this.rating,
    this.size = 13,
    this.color = AppColors.yellow,
    this.animate = true,
    this.showEmpty = false,
  });

  final double rating;
  final double size;
  final Color color;
  final bool animate;

  /// Draw the unfilled remainder in a muted tint (detail screen does).
  final bool showEmpty;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = rating - full >= 0.35;

    final stars = <Widget>[
      for (var i = 0; i < 5; i++)
        Icon(
          i < full
              ? Icons.star_rounded
              : (i == full && hasHalf)
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: i < full || (i == full && hasHalf)
              ? color
              : showEmpty
              ? color.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
    ];

    if (!animate) {
      return Row(mainAxisSize: MainAxisSize.min, children: stars);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < stars.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.normal,
            curve: Interval(i * 0.12, 1, curve: Curves.easeOutBack),
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: stars[i],
          ),
      ],
    );
  }
}

/// Green "Available" indicator with a soft halo when live.
class KwAvailability extends StatelessWidget {
  const KwAvailability({
    super.key,
    required this.available,
    this.label,
    this.fontSize = 11,
  });

  final bool available;
  final String? label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (!available && label == null) return const SizedBox.shrink();
    final color = available ? AppColors.success : AppColors.muted;
    final text = label ?? (available ? context.s.available : context.s.busy);

    Widget dot = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (available) {
      dot = PulseRings(color: color, maxRadius: 9, ringCount: 2, child: dot);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 14, height: 14, child: Center(child: dot)),
        const SizedBox(width: 2),
        // Flexible so a long label ("Available – turant bulao") truncates
        // instead of pushing past the card edge on narrow screens.
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.micro.copyWith(
              color: available ? AppColors.success : AppColors.muted,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS-style switch drawn to match the mockup's yellow toggle, with a thumb
/// that stretches slightly as it travels.
class KwToggle extends StatelessWidget {
  const KwToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Pressable(
        scale: 0.92,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: value ? 1 : 0, end: value ? 1 : 0),
          duration: Motion.normal,
          curve: Motion.spring,
          builder: (context, t, _) {
            const trackW = 44.0;
            const trackH = 24.0;
            const thumb = 20.0;
            // Squash-and-stretch: widest at the midpoint of the travel.
            final stretch = 1 + (0.35 * (1 - (t - 0.5).abs() * 2));
            final thumbW = thumb * stretch;
            final left = 2 + t * (trackW - thumb - 4);

            return Container(
              width: trackW,
              height: trackH,
              decoration: BoxDecoration(
                color: Color.lerp(AppColors.toggleOff, AppColors.yellow, t),
                borderRadius: BorderRadius.circular(trackH / 2),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: left - (thumbW - thumb) / 2,
                    top: 2,
                    child: Container(
                      width: thumbW,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(thumb / 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Uppercase group heading above menu cards.
class KwSectionTitle extends StatelessWidget {
  const KwSectionTitle(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: Gap.md, top: Gap.xs),
      child: Text(text.toUpperCase(), style: AppType.sectionTitle),
    );
  }
}

/// One row of a settings/menu card: icon, label, optional subtitle, trailing.
class KwMenuRow extends StatelessWidget {
  const KwMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.foreground = AppColors.black,
    this.divider = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color foreground;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoverRow(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.x3l,
              vertical: Gap.xxl,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: foreground),
                Gap.hXl,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppType.bodyStrong.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(subtitle!, style: AppType.caption),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[Gap.hMd, trailing!],
                if (showChevron) ...[
                  Gap.hSm,
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: foreground == AppColors.black
                        ? AppColors.arrow
                        : foreground,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (divider)
          const Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
      ],
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        scale: 0.99,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.instant,
          color: _hovered && widget.onTap != null
              ? const Color(0xFFFAFAFA)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Card that groups [KwMenuRow]s, trimming the last divider.
class KwMenuCard extends StatelessWidget {
  const KwMenuCard({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: Gap.xl),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: Radii.rMd,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Yellow numeric/status badge (e.g. the "2" on Active Bookings).
class KwBadge extends StatelessWidget {
  const KwBadge({
    super.key,
    required this.label,
    this.background = AppColors.yellow,
    this.foreground = AppColors.black,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: Radii.rPill),
      child: Text(
        label,
        style: AppType.micro.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Empty-state block with a gently floating icon.
class KwEmptyState extends StatelessWidget {
  const KwEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x4l,
          vertical: Gap.x8l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Floating(
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.yellowLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: AppColors.yellowDark),
              ),
            ),
            Gap.v20,
            Text(title, style: AppType.h4, textAlign: TextAlign.center),
            if (message != null) ...[
              Gap.vSm,
              Text(
                message!,
                style: AppType.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[Gap.v20, action!],
          ],
        ),
      ),
    );
  }
}
