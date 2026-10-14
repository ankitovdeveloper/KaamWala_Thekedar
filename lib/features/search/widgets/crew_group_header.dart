import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';

/// Heads one neighbourhood group in the crew search: which area it is, how far
/// off and how tightly packed, what it costs, and the button that books the lot.
///
/// The workers themselves are the ordinary [LabourCard]s listed underneath.
class CrewGroupHeader extends StatelessWidget {
  const CrewGroupHeader({super.key, required this.group, required this.onBook});

  final LabourGroup group;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    final distance = group.distanceKm < 1
        ? s.metresAway((group.distanceKm * 1000).round())
        : s.kmAway(group.distanceKm.toStringAsFixed(1));

    // "0.0 km of each other" reads as a typo for a pair living on the same lane.
    final spread = group.spreadKm < 0.1 ? 0.1 : group.spreadKm;

    return KwCard(
      margin: const EdgeInsets.only(bottom: Gap.lg),
      padding: const EdgeInsets.all(Gap.xxl),
      color: AppColors.yellowLight,
      borderColor: AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 20),
              Gap.hMd,
              Expanded(
                child: Text(
                  group.area == null
                      ? s.crewAreaTitle(group.index)
                      : '${s.crewAreaTitle(group.index)} · ${group.area}',
                  style: AppType.bodyStrong.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!group.complete) ...[
                Gap.hMd,
                KwPill(
                  label: s.crewOnlyOf(group.size, group.needed),
                  background: AppColors.white,
                  foreground: AppColors.pendingText,
                  dense: true,
                ),
              ],
            ],
          ),
          Gap.vSm,
          Text(
            '$distance · ${s.crewWithin(spread.toStringAsFixed(1))}',
            style: AppType.caption,
          ),
          Gap.vLg,
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.crewTotalEstimate(group.size)} · '
                  '₹${group.dailyTotal}',
                  style: AppType.label,
                ),
              ),
              Gap.hLg,
              KwButton(
                label: s.crewBookGroup(group.size),
                icon: Icons.event_available_rounded,
                size: KwButtonSize.small,
                expand: false,
                onPressed: onBook,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The horizontal line between two areas in the crew search.
class AreaDivider extends StatelessWidget {
  const AreaDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(height: 1, thickness: 1, color: AppColors.borderStrong),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xl),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
            child: Text(
              label.toUpperCase(),
              style: AppType.nano.copyWith(
                color: AppColors.muted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}
