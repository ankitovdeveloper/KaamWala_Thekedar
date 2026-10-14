import 'package:flutter/material.dart';

import '../../../core/animations/entrance.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_config.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
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
    // On by default: a search that offers workers who are off duty right now
    // wastes the Thekedar's time, so the useful list is the starting point and
    // seeing everyone is the deliberate step.
    this.availableOnly = true,
    this.radiusKm = ApiConfig.defaultRadiusKm,
    this.sort = LabourSort.distance,
    this.crewSize = 1,
  });

  static const _rateCeiling = 1000.0;

  /// The most workers one crew booking may ask for (`Crew::MAX_SIZE`).
  static const maxCrewSize = 20;
  static const rateFloor = 200.0;
  static const rateCeiling = _rateCeiling;

  /// The API filters on a single skill, not a set.
  final int? skillId;
  final double maxRate;
  final bool availableOnly;
  final int radiusKm;
  final LabourSort sort;

  /// How many workers of [skillId] the Thekedar needs. Above one, the search
  /// groups workers by neighbourhood instead of listing them one by one.
  final int crewSize;

  /// True when the search should come back as same-area groups. A crew needs a
  /// skill to be about — "4 workers" of nothing in particular has no groups.
  bool get isCrew => crewSize > 1 && skillId != null;

  bool get isDefault =>
      skillId == null &&
      maxRate >= _rateCeiling &&
      availableOnly &&
      radiusKm == ApiConfig.defaultRadiusKm &&
      crewSize == 1;

  /// Count shown on the Filter button's badge.
  int get activeCount =>
      (skillId != null ? 1 : 0) +
      (maxRate < _rateCeiling ? 1 : 0) +
      (availableOnly ? 0 : 1) +
      (radiusKm != ApiConfig.defaultRadiusKm ? 1 : 0) +
      (crewSize > 1 ? 1 : 0);

  LabourFilters copyWith({
    Object? skillId = _unset,
    double? maxRate,
    bool? availableOnly,
    int? radiusKm,
    LabourSort? sort,
    int? crewSize,
  }) => LabourFilters(
    skillId: skillId == _unset ? this.skillId : skillId as int?,
    maxRate: maxRate ?? this.maxRate,
    availableOnly: availableOnly ?? this.availableOnly,
    radiusKm: radiusKm ?? this.radiusKm,
    sort: sort ?? this.sort,
    crewSize: crewSize ?? this.crewSize,
  );

  static const _unset = Object();

  /// The parts the API can't express. `is_on_duty` is already enforced server
  /// side, so the availability toggle is only meaningful for mock data.
  List<Labour> applyLocal(List<Labour> input) {
    final filtered = input.where((l) {
      if (availableOnly && !l.isOnDuty) return false;
      if (l.dailyRate > maxRate) return false;

      // Filter by skill if selected
      if (skillId != null) {
        final hasSkill = l.skills.any((s) => s.id == skillId);
        if (!hasSkill) return false;
      }

      return true;
    }).toList();

    switch (sort) {
      case LabourSort.distance:
        filtered.sort((a, b) => (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity));
      case LabourSort.rating:
        filtered.sort((a, b) => b.avgRating.compareTo(a.avgRating));
      case LabourSort.priceLow:
        filtered.sort((a, b) => a.dailyRate.compareTo(b.dailyRate));
      case LabourSort.priceHigh:
        filtered.sort((a, b) => b.dailyRate.compareTo(a.dailyRate));
    }

    return filtered;
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
    final s = context.s;

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
                  Text(s.filterTitle, style: AppType.h3),
                  const Spacer(),
                  if (_draft.activeCount > 0)
                    Pressable(
                      scale: 0.94,
                      onTap: () => setState(() {
                        _draft = LabourFilters(sort: _draft.sort);
                      }),
                      child: Text(
                        s.reset,
                        style: AppType.buttonSmall.copyWith(
                          color: AppColors.muted,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
              Gap.v20,
              KwSectionTitle(s.workType),
              if (widget.skills.isEmpty)
                Text(s.skillsNotLoaded, style: AppType.caption)
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
              KwSectionTitle(s.crewSizeTitle),
              _CrewSizePicker(
                size: _draft.crewSize,
                needsSkill: _draft.skillId == null,
                onChanged: (n) =>
                    setState(() => _draft = _draft.copyWith(crewSize: n)),
              ),
              Gap.v24,
              if (_draft.crewSize == 1) ...[
                Row(
                  children: [
                    Expanded(child: KwSectionTitle(s.maxRate)),
                    Text(
                      _draft.maxRate >= LabourFilters.rateCeiling
                          ? s.noLimit
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
              ],
              Row(
                children: [
                  Expanded(child: KwSectionTitle(s.howFar)),
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
                        Text(s.onlyAvailable, style: AppType.bodyStrong),
                        Text(s.onDutyNow, style: AppType.caption),
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
                label: s.applyFilter,
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
/// Radius on its own, reachable in one tap from the map.
///
/// It is also in [FilterSheet], but radius is the one parameter the map draws,
/// so changing it wants a shorter path than opening the full filter form.
class RadiusSheet extends StatefulWidget {
  const RadiusSheet({super.key, required this.current});

  final int current;

  static Future<int?> show(BuildContext context, int current) =>
      showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppColors.white,
        builder: (_) => RadiusSheet(current: current),
      );

  @override
  State<RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends State<RadiusSheet> {
  late int _km = widget.current;

  /// The jumps people actually think in, rather than every integer.
  static const _presets = [2, 5, 10, 25, 50];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.x4l, 0, Gap.x4l, Gap.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(context.s.howFar, style: AppType.h3)),
                Text('$_km km', style: AppType.h3),
              ],
            ),
            Gap.vMd,
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.yellow,
                inactiveTrackColor: AppColors.surfaceAlt,
                thumbColor: AppColors.black,
                overlayColor: AppColors.yellow.withValues(alpha: 0.2),
                trackHeight: 5,
              ),
              child: Slider(
                value: _km.clamp(1, 50).toDouble(),
                min: 1,
                max: 50,
                divisions: 49,
                onChanged: (v) => setState(() => _km = v.round()),
              ),
            ),
            Gap.vMd,
            Wrap(
              spacing: Gap.md,
              children: [
                for (final preset in _presets)
                  ChoiceChip(
                    label: Text('$preset km'),
                    labelStyle: AppType.buttonSmall.copyWith(fontSize: 12),
                    selected: _km == preset,
                    showCheckmark: false,
                    backgroundColor: AppColors.white,
                    selectedColor: AppColors.yellow,
                    side: const BorderSide(color: AppColors.border),
                    onSelected: (_) => setState(() => _km = preset),
                  ),
              ],
            ),
            Gap.v20,
            KwButton(
              label: context.s.searchThisArea,
              onPressed: () => Navigator.of(context).pop(_km),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final s = context.s;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.x4l, 0, Gap.x4l, Gap.md),
            child: Text(s.sortTitle, style: AppType.h3),
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
                  label: option.labelIn(s),
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

/// "How many workers?" — the 1 / 2 / 3 / 5 tiles, plus a stepper for any other
/// number (a crew of four is as ordinary as a crew of five).
class _CrewSizePicker extends StatelessWidget {
  const _CrewSizePicker({
    required this.size,
    required this.needsSkill,
    required this.onChanged,
  });

  final int size;

  /// No work type picked yet, so a crew has nothing to group.
  final bool needsSkill;
  final ValueChanged<int> onChanged;

  static const _presets = [1, 2, 3, 5];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final labels = {1: s.crewSolo, 2: s.crewPair, 3: s.crewTeam, 5: s.crewCrew};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final n in _presets) ...[
              Expanded(
                child: _CountTile(
                  count: n,
                  label: labels[n]!,
                  selected: size == n,
                  onTap: () => onChanged(n),
                ),
              ),
              if (n != _presets.last) Gap.hMd,
            ],
          ],
        ),
        Gap.vLg,
        Row(
          children: [
            Expanded(child: Text(s.crewOtherNumber, style: AppType.caption)),
            _StepButton(
              icon: Icons.remove_rounded,
              onTap: size > 1 ? () => onChanged(size - 1) : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$size',
                textAlign: TextAlign.center,
                style: AppType.h4,
              ),
            ),
            _StepButton(
              icon: Icons.add_rounded,
              onTap: size < LabourFilters.maxCrewSize
                  ? () => onChanged(size + 1)
                  : null,
            ),
          ],
        ),
        if (size > 1) ...[
          Gap.vMd,
          Text(s.crewHelper(size), style: AppType.caption),
          if (needsSkill) ...[
            Gap.vSm,
            Text(
              s.crewPickSkill,
              style: AppType.caption.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.count,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: const EdgeInsets.symmetric(vertical: Gap.xl),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellowLight : AppColors.white,
          borderRadius: Radii.rSm,
          border: Border.all(
            color: selected ? AppColors.yellow : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: AppType.h3),
            Text(
              label.toUpperCase(),
              style: AppType.nano.copyWith(fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.border : AppColors.black,
        ),
      ),
    );
  }
}
