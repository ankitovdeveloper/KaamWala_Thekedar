import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/animations/pressable.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const kNavDestinations = <NavDestination>[
  NavDestination(
    icon: Icons.map_outlined,
    activeIcon: Icons.map_rounded,
    label: 'Search',
  ),
  NavDestination(
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_month_rounded,
    label: 'Bookings',
  ),
  NavDestination(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
  NavDestination(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Account',
  ),
];

/// Black bar with the yellow active item from the mockups, plus three things
/// the static design implies but can't show: a pill that slides between items,
/// an icon that pops on selection, and a label that fades up underneath.
class KwBottomNav extends StatelessWidget {
  const KwBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.destinations = kNavDestinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      color: AppColors.black,
      padding: EdgeInsets.only(
        top: Gap.md,
        bottom: Gap.md + (bottomInset > 0 ? bottomInset * 0.6 : 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / destinations.length;
          return Stack(
            children: [
              // Sliding indicator behind the active item.
              AnimatedPositioned(
                duration: Motion.normal,
                curve: Motion.emphasized,
                left: itemWidth * currentIndex,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Center(
                  child: AnimatedContainer(
                    duration: Motion.normal,
                    curve: Motion.emphasized,
                    width: itemWidth * 0.62,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.14),
                      borderRadius: Radii.rPill,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        destination: destinations[i],
                        selected: i == currentIndex,
                        onTap: () {
                          if (i != currentIndex) {
                            HapticFeedback.selectionClick();
                            onSelected(i);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      haptic: false,
      semanticLabel: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: selected ? 1 : 0, end: selected ? 1 : 0),
              duration: Motion.normal,
              curve: Motion.spring,
              builder: (context, t, _) => Transform.scale(
                // Overshoot then settle — a small "pop" on selection.
                scale: 1 + 0.14 * t,
                child: Transform.translate(
                  offset: Offset(0, -1.5 * t),
                  child: Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: 22,
                    color: Color.lerp(
                      AppColors.onDarkIdle,
                      AppColors.yellow,
                      t,
                    ),
                  ),
                ),
              ),
            ),
            Gap.vXs,
            AnimatedDefaultTextStyle(
              duration: Motion.normal,
              curve: Motion.enter,
              style: AppType.nano.copyWith(
                color: selected ? AppColors.yellow : AppColors.onDarkIdle,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(destination.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide-screen counterpart. Same visual language — black surface, yellow
/// active state — but vertical, with an indicator that slides in the Y axis.
class KwNavRail extends StatelessWidget {
  const KwNavRail({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.extended = false,
    this.destinations = kNavDestinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool extended;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final width = extended ? 200.0 : 82.0;

    return Container(
      width: width,
      color: AppColors.black,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap.v24,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.x3l),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      size: 22,
                      color: AppColors.black,
                    ),
                  ),
                  if (extended) ...[
                    Gap.hLg,
                    Flexible(
                      child: Text(
                        'KaamWala',
                        style: AppType.h4.copyWith(color: AppColors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Gap.v32,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const itemHeight = 62.0;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: Motion.normal,
                        curve: Motion.emphasized,
                        top: itemHeight * currentIndex,
                        left: Gap.md,
                        right: Gap.md,
                        height: itemHeight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.yellow.withValues(alpha: 0.14),
                            borderRadius: Radii.rMd,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          for (var i = 0; i < destinations.length; i++)
                            SizedBox(
                              height: itemHeight,
                              child: _RailItem(
                                destination: destinations[i],
                                selected: i == currentIndex,
                                extended: extended,
                                onTap: () {
                                  if (i != currentIndex) {
                                    HapticFeedback.selectionClick();
                                    onSelected(i);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.yellow : AppColors.onDarkIdle;

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      haptic: false,
      semanticLabel: destination.label,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: extended ? Gap.x4l : Gap.md),
        child: extended
            ? Row(
                children: [
                  Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: 22,
                    color: color,
                  ),
                  Gap.hXl,
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: Motion.normal,
                      style: AppType.body.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      child: Text(
                        destination.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: 22,
                    color: color,
                  ),
                  Gap.vXs,
                  AnimatedDefaultTextStyle(
                    duration: Motion.normal,
                    style: AppType.nano.copyWith(color: color),
                    child: Text(destination.label),
                  ),
                ],
              ),
      ),
    );
  }
}
