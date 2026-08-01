import 'package:flutter/material.dart';

import '../../../core/animations/entrance.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_config.dart';
import '../../../data/models/models.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';

/// Search parameters for `GET /v1/thekedar/labour`.
///
/// `skill_id` and `radius` are server-side; the max-rate cap has no query
/// parameter yet, so it's applied client-side after the response — see
/// [applyLocal].
class LabourFilters {
  const LabourFilters({
    this.skillId,
    this.maxRate = _rateCeiling,
    this.availableOnly = false,
    this.radiusKm = ApiConfig.defaultRadiusKm,
    this.sort = LabourSort.distance,
  });

  static const _rateCeiling = 1000.0;
  static const rateFloor = 200.0;
  static const rateCeiling = _rateCeiling;

  /// The API filters on a single skill, not a set.
  final int? skillId;
  final double maxRate;
  final bool availableOnly;
  final int radiusKm;
  final LabourSort sort;

  bool get isDefault =>
      skillId == null &&
      maxRate >= _rateCeiling &&
      !availableOnly &&
      radiusKm == ApiConfig.defaultRadiusKm;

  /// Count shown on the Filter button's badge.
  int get activeCount =>
      (skillId != null ? 1 : 0) +
      (maxRate < _rateCeiling ? 1 : 0) +
      (availableOnly ? 1 : 0) +
      (radiusKm != ApiConfig.defaultRadiusKm ? 1 : 0);

  LabourFilters copyWith({
    Object? skillId = _unset,
    double? maxRate,
    bool? availableOnly,
    int? radiusKm,
    LabourSort? sort,
  }) => LabourFilters(
    skillId: skillId == _unset ? this.skillId : skillId as int?,
    maxRate: maxRate ?? this.maxRate,
    availableOnly: availableOnly ?? this.availableOnly,
    radiusKm: radiusKm ?? this.radiusKm,
    sort: sort ?? this.sort,
  );

  static const _unset = Object();

  /// The parts the API can't express. `is_on_duty` is already enforced server
  /// side, so the availability toggle is only meaningful for mock data.
  List<Labour> applyLocal(List<Labour> input) {
    return input.where((l) {
      if (availableOnly && !l.isOnDuty) return false;
      if (l.dailyRate > maxRate) return false;
      return true;
    }).toList();
  }
}

/// Bottom sheet for skill / rate / radius / availability.
class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initial, required this.skills});

  final LabourFilters initial;
  final List<Skill> skills;

  static Future<LabourFilters?> show(
    BuildContext context, {
    required LabourFilters initial,
    required List<Skill> skills,
  }) => showModalBottomSheet<LabourFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    builder: (_) => FilterSheet(initial: initial, skills: skills),
  );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late LabourFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: Gap.x4l,
          right: Gap.x4l,
          bottom: Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: Stagger.wrap(
            step: const Duration(milliseconds: 45),
            children: [
              Row(
                children: [
                  Text('Filter karein', style: AppType.h3),
                  const Spacer(),
                  if (_draft.activeCount > 0)
                    Pressable(
                      scale: 0.94,
                      onTap: () => setState(() {
                        _draft = LabourFilters(sort: _draft.sort);
                      }),
                      child: Text(
                        'Reset',
                        style: AppType.buttonSmall.copyWith(
                          color: AppColors.muted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              Gap.v20,
              const KwSectionTitle('Kaam ka type'),
              if (widget.skills.isEmpty)
                Text('Skill list load nahi hui', style: AppType.caption)
              else
                Wrap(
                  spacing: Gap.md,
                  runSpacing: Gap.md,
                  children: [
                    for (final skill in widget.skills)
                      _SkillChip(
                        skill: skill,
                        selected: _draft.skillId == skill.id,
                        // Tapping the active chip clears it — the API takes
                        // at most one skill_id.
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            skillId: _draft.skillId == skill.id
                                ? null
                                : skill.id,
                          );
                        }),
                      ),
                  ],
                ),
              Gap.v24,
              Row(
                children: [
                  const Expanded(child: KwSectionTitle('Zyada se zyada rate')),
                  Text(
                    _draft.maxRate >= LabourFilters.rateCeiling
                        ? 'Koi limit nahi'
                        : '₹${_draft.maxRate.round()}',
                    style: AppType.bodyStrong,
                  ),
                ],
              ),
              _slider(
                value: _draft.maxRate,
                min: LabourFilters.rateFloor,
                max: LabourFilters.rateCeiling,
                divisions: 16,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(maxRate: v)),
              ),
              Gap.vXl,
              Row(
                children: [
                  const Expanded(child: KwSectionTitle('Kitni door tak')),
                  Text('${_draft.radiusKm} km', style: AppType.bodyStrong),
                ],
              ),
              _slider(
                value: _draft.radiusKm.toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(radiusKm: v.round()),
                ),
              ),
              Gap.vXl,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Sirf available', style: AppType.bodyStrong),
                        Text('Jo abhi duty pe hain', style: AppType.caption),
                      ],
                    ),
                  ),
                  KwToggle(
                    value: _draft.availableOnly,
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(availableOnly: v),
                    ),
                  ),
                ],
              ),
              Gap.v24,
              KwButton(
                label: 'Filter lagao',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(_draft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) => SliderTheme(
    data: SliderTheme.of(context).copyWith(
      activeTrackColor: AppColors.yellow,
      inactiveTrackColor: AppColors.surfaceAlt,
      thumbColor: AppColors.black,
      overlayColor: AppColors.yellow.withValues(alpha: 0.2),
      trackHeight: 5,
    ),
    child: Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
    ),
  );
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.skill,
    required this.selected,
    required this.onTap,
  });

  final Skill skill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.93,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xxl,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : AppColors.white,
          borderRadius: Radii.rPill,
          border: Border.all(
            color: selected ? AppColors.yellow : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(skill.emoji, style: const TextStyle(fontSize: 13)),
            Gap.hSm,
            Text(
              skill.name,
              style: AppType.buttonSmall.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            AnimatedSize(
              duration: Motion.fast,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(left: Gap.sm),
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.black,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact sort picker — maps onto `?sort=distance|rating|price_low|price_high`.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.current});

  final LabourSort current;

  static Future<LabourSort?> show(BuildContext context, LabourSort current) =>
      showModalBottomSheet<LabourSort>(
        context: context,
        backgroundColor: AppColors.white,
        builder: (_) => SortSheet(current: current),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.x4l, 0, Gap.x4l, Gap.md),
            child: Text('Sort karein', style: AppType.h3),
          ),
          ...Stagger.wrap(
            step: const Duration(milliseconds: 40),
            offset: 10,
            children: [
              for (final option in LabourSort.values)
                KwMenuRow(
                  icon: switch (option) {
                    LabourSort.distance => Icons.near_me_outlined,
                    LabourSort.rating => Icons.star_outline_rounded,
                    LabourSort.priceLow => Icons.trending_down_rounded,
                    LabourSort.priceHigh => Icons.trending_up_rounded,
                  },
                  label: option.label,
                  showChevron: false,
                  divider: option != LabourSort.values.last,
                  trailing: option == current
                      ? const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: AppColors.yellowDark,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
          Gap.v20,
        ],
      ),
    );
  }
}
