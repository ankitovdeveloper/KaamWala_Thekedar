import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/kw_bottom_nav.dart';
import '../../widgets/shared_axis_stack.dart';
import '../account/account_screen.dart';
import '../bookings/bookings_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';

/// Owns tab state for the four main destinations. Layout flips from a bottom
/// bar to a side rail once the window is wide enough to spare the width.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => HomeShellState();

  /// Lets any descendant jump tabs — e.g. Profile → "Active Bookings".
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();
}

class HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  void goToTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const SearchScreen(),
      const BookingsScreen(),
      const ProfileScreen(),
      const AccountScreen(),
    ];

    final content = SharedAxisIndexedStack(index: _index, children: pages);

    if (context.usesRail) {
      // Rail is only extended when there's genuinely room for labels.
      final extended = context.screenWidth >= 1180;
      return ColoredBox(
        color: AppColors.black,
        child: Row(
          children: [
            KwNavRail(
              currentIndex: _index,
              onSelected: goToTab,
              extended: extended,
            ),
            Expanded(child: ClipRect(child: content)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(child: ClipRect(child: content)),
        KwBottomNav(currentIndex: _index, onSelected: goToTab),
      ],
    );
  }
}
