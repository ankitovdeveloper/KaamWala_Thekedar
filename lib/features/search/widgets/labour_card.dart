import 'package:flutter/material.dart';

import '../../../core/animations/effects.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';

/// Row card in the search results. The avatar carries a [Hero] tag so it flies
/// into the detail screen's large avatar on tap.
class LabourCard extends StatelessWidget {
  const LabourCard({
    super.key,
    required this.labour,
    required this.onTap,
    required this.onConnect,
    this.selected = false,
  });

  final Labour labour;
  final VoidCallback onTap;
  final VoidCallback onConnect;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return KwCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.all(Gap.xxl),
      borderColor: selected ? AppColors.yellow : AppColors.border,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The side-by-side layout needs room for the info column *and* the
          // Connect button. Below that — narrow phone, or a large font scale
          // inflating the button — Connect drops to its own full-width row.
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final stacked = constraints.maxWidth < 300 * scale;

          final head = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(),
              Gap.hXl,
              Expanded(child: _info(context)),
              if (!stacked) ...[
                Gap.hLg,
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: KwChipButton(
                    label: context.s.connect,
                    filled: true,
                    onPressed: onConnect,
                  ),
                ),
              ],
            ],
          );

          if (!stacked) return head;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              head,
              Gap.vXl,
              KwButton(
                label: context.s.connect,
                size: KwButtonSize.small,
                onPressed: onConnect,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _avatar() {
    return Hero(
      tag: 'labour-avatar-${labour.id}',
      // Flutter can't animate arbitrary widget trees between routes, so the
      // flight frame is a plain circle without the online dot.
      flightShuttleBuilder: (_, _, _, _, _) =>
          KwAvatar(initials: labour.initials, size: 50),
      child: KwAvatar(
        initials: labour.initials,
        size: 50,
        online: labour.isOnDuty,
      ),
    );
  }

  Widget _info(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labour.name,
          style: AppType.bodyStrong.copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        // Stars are fixed-width icons, so the rating text is what gives way.
        Row(
          children: [
            KwStars(rating: labour.avgRating, size: 13),
            Gap.hXs,
            Flexible(
              child: Text(
                '${labour.avgRating} (${labour.ratingsCount})',
                style: AppType.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Gap.vSm,
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final skill in labour.skills.take(2))
              KwPill(label: skill.label, dense: true),
          ],
        ),
        Gap.vSm,
        // Price + availability wrap rather than overflow when the font scale
        // is large or the card is narrow.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Gap.sm,
          runSpacing: 2,
          children: [
            Text('₹${labour.dailyRate}', style: AppType.price),
            Text(context.s.perDayToday, style: AppType.micro),
            if (labour.isOnDuty) const KwAvailability(available: true),
          ],
        ),
      ],
    );
  }
}

/// Skeleton shown while results load — same silhouette as [LabourCard] so the
/// list doesn't jump when real data lands.
class LabourCardSkeleton extends StatelessWidget {
  const LabourCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return KwCard(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.all(Gap.xxl),
      child: const Shimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonCircle(size: 50),
            Gap.hXl,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 130, height: 14),
                  Gap.vMd,
                  _SkeletonBar(width: 90, height: 11),
                  Gap.vMd,
                  _SkeletonBar(width: 160, height: 16),
                  Gap.vMd,
                  _SkeletonBar(width: 110, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.surfaceAlt,
      shape: BoxShape.circle,
    ),
  );
}
