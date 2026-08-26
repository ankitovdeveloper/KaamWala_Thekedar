import 'package:flutter/material.dart';

import '../core/animations/effects.dart';
import '../core/animations/pressable.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

enum KwButtonVariant { yellow, outline, dark, ghost, danger }

enum KwButtonSize { normal, large, small }

/// The app's one button. Handles press-scale, an inline busy state that morphs
/// the label into a spinner, and a success tick — so callers never have to
/// juggle a separate loading widget.
class KwButton extends StatelessWidget {
  const KwButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = KwButtonVariant.yellow,
    this.size = KwButtonSize.normal,
    this.busy = false,
    this.succeeded = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KwButtonVariant variant;
  final KwButtonSize size;

  /// Swaps the label for a spinner and blocks taps.
  final bool busy;

  /// Swaps the label for a tick — hold briefly before navigating away.
  final bool succeeded;
  final bool expand;

  bool get _locked => busy || succeeded || onPressed == null;

  ({Color bg, Color fg, Color? border}) get _palette => switch (variant) {
    KwButtonVariant.yellow => (
      bg: AppColors.yellow,
      fg: AppColors.black,
      border: null,
    ),
    KwButtonVariant.outline => (
      bg: AppColors.white,
      fg: AppColors.black,
      border: AppColors.borderStrong,
    ),
    KwButtonVariant.dark => (
      bg: AppColors.black,
      fg: AppColors.yellow,
      border: null,
    ),
    KwButtonVariant.ghost => (
      bg: AppColors.veil06,
      fg: AppColors.black,
      border: null,
    ),
    KwButtonVariant.danger => (
      bg: AppColors.white,
      fg: AppColors.danger,
      border: const Color(0x33D32F2F),
    ),
  };

  EdgeInsets get _padding => switch (size) {
    KwButtonSize.large => const EdgeInsets.symmetric(
      horizontal: Gap.x4l,
      vertical: 15,
    ),
    KwButtonSize.normal => const EdgeInsets.symmetric(
      horizontal: Gap.x4l,
      vertical: Gap.xxl,
    ),
    KwButtonSize.small => const EdgeInsets.symmetric(
      horizontal: Gap.xxl,
      vertical: Gap.sm,
    ),
  };

  TextStyle get _textStyle => switch (size) {
    KwButtonSize.large => AppType.buttonLarge,
    KwButtonSize.normal => AppType.button,
    KwButtonSize.small => AppType.buttonSmall,
  };

  double get _iconSize => switch (size) {
    KwButtonSize.large => 20,
    KwButtonSize.normal => 18,
    KwButtonSize.small => 15,
  };

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final fg = _locked && onPressed == null && !busy && !succeeded
        ? palette.fg.withValues(alpha: 0.4)
        : palette.fg;

    final content = SwapIn(
      child: busy
          ? SizedBox(
              key: const ValueKey('busy'),
              height: _iconSize,
              width: _iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            )
          : succeeded
          ? Icon(
              Icons.check_rounded,
              key: const ValueKey('done'),
              color: fg,
              size: _iconSize + 2,
            )
          : Row(
              key: ValueKey('label:$label'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: _iconSize, color: fg),
                  Gap.hMd,
                ],
                Flexible(
                  child: Text(
                    label,
                    style: _textStyle.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    return Pressable(
      onTap: _locked ? null : onPressed,
      scale: 0.97,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        width: expand ? double.infinity : null,
        padding: _padding,
        decoration: BoxDecoration(
          color: succeeded && variant == KwButtonVariant.yellow
              ? AppColors.yellowDark
              // Fade the fill when disabled, but scale the palette's own alpha
              // rather than setting an absolute one — `ghost` is a translucent
              // veil, and forcing alpha to 1 would paint it solid black.
              : onPressed == null && !busy
              ? palette.bg.withValues(alpha: palette.bg.a * 0.55)
              : palette.bg,
          borderRadius: Radii.rSm,
          border: palette.border == null
              ? null
              : Border.all(color: palette.border!, width: 1.5),
        ),
        child: Center(heightFactor: 1, child: content),
      ),
    );
  }
}

/// Small pill button used inside cards (Connect / Call / Details / Review do).
class KwChipButton extends StatelessWidget {
  const KwChipButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.black;
    return Pressable(
      onTap: onPressed,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xxl,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: filled ? AppColors.yellow : AppColors.white,
          borderRadius: Radii.rSm,
          border: filled
              ? null
              : Border.all(
                  color: danger ? const Color(0x33D32F2F) : AppColors.border,
                  width: 0.5,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            // Flexible, not a bare Text: these chips live in a Wrap, which hands
            // each child the full row width to measure against, so a long label
            // at large font scale paints straight past the chip's own edge.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.buttonSmall.copyWith(
                  color: fg,
                  fontWeight: filled ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular icon button sitting on the yellow header bars.
class KwIconButton extends StatelessWidget {
  const KwIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconSize = 18,
    this.background = AppColors.veil10,
    this.foreground = AppColors.black,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onPressed,
      scale: 0.88,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize, color: foreground),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
