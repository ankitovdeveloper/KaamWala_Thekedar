import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/animations/pressable.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/session.dart';

/// Maps onto `GET /v1/thekedar/bookings?tab=all|active|pending|done`.
enum BookingTab {
  all('all'),
  active('active'),
  pending('pending'),
  done('done');

  const BookingTab(this.wire);
  final String wire;

  String labelIn(AppStrings s) => switch (this) {
    BookingTab.all => s.tabAll,
    BookingTab.active => s.tabActive,
    BookingTab.pending => s.tabPending,
    BookingTab.done => s.tabDone,
  };
}

/// Filter tabs with a black pill that slides between options rather than
/// snapping. Measured per-tab so the pill matches each label's real width.
class BookingTabs extends StatelessWidget {
  const BookingTabs({
    super.key,
    required this.current,
    required this.onChanged,
    this.counts = const {},
  });

  final BookingTab current;
  final ValueChanged<BookingTab> onChanged;
  final Map<BookingTab, int> counts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        Gap.xxl,
        context.pagePadding,
        0,
      ),
      child: ContentWidth(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final tab in BookingTab.values) ...[
                if (tab != BookingTab.values.first) Gap.hMd,
                _Tab(
                  tab: tab,
                  selected: tab == current,
                  count: counts[tab],
                  onTap: () {
                    if (tab == current) return;
                    HapticFeedback.selectionClick();
                    onChanged(tab);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final BookingTab tab;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      haptic: false,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.emphasized,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.x3l,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.white,
          borderRadius: Radii.rPill,
          border: Border.all(
            color: selected ? AppColors.black : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: Motion.normal,
              style: AppType.buttonSmall.copyWith(
                color: selected ? AppColors.yellow : AppColors.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(tab.labelIn(context.s)),
            ),
            if (count != null && count! > 0) ...[
              Gap.hSm,
              AnimatedContainer(
                duration: Motion.normal,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.yellow.withValues(alpha: 0.22)
                      : AppColors.surfaceAlt,
                  borderRadius: Radii.rPill,
                ),
                child: Text(
                  '$count',
                  style: AppType.nano.copyWith(
                    fontSize: 10,
                    color: selected ? AppColors.yellow : AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
