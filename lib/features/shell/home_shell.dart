import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../data/session.dart' show unawaited;
import '../../widgets/kw_bottom_nav.dart';
import '../../widgets/shared_axis_stack.dart';
import '../account/account_screen.dart';
import '../bookings/bookings_screen.dart';
import '../location/location_prompt.dart';
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

class HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    // Coming back from the background counts as opening the app — someone who
    // left the phone in a pocket on the way to a new site never restarts it.
    WidgetsBinding.instance.addObserver(this);
    // Post-frame: the sheet needs a Navigator, and the shell is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askForLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _askForLocation();
  }

  /// Asks where the Thekedar is, unless a point saved within the last four
  /// hours already answers that — [LocationPrompt] owns that decision.
  void _askForLocation() {
    if (!mounted) return;
    unawaited(LocationPrompt.maybeShow(context));
  }

  /// Tabs the Thekedar came from, oldest first. The system back button walks this
  /// back before it lets the app close, so back means "where I was" not "quit".
  final List<int> _tabHistory = <int>[];

  void goToTab(int index) {
    if (index == _index) return;
    _tabHistory.add(_index);
    _show(index);
  }

  /// Switches the visible tab without recording it in [_tabHistory]; used by a
  /// normal selection and by a back press alike.
  void _show(int index) => setState(() => _index = index);

  /// The system back press once no pushed route is left above the shell.
  void _onBack() {
    if (_tabHistory.isNotEmpty) {
      _show(_tabHistory.removeLast());
    } else if (_index != 0) {
      _show(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the first tab with nothing in history lets the back press close the
    // app; everywhere else it is handled by [_onBack] first.
    return PopScope(
      canPop: _index == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
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
        // Flutter reads the overlay style from whatever is annotated at the
        // bottom edge of the screen. The page's own KwScaffold only covers the
        // area above this bar, so the nav bar has to declare its own style —
        // without it Android paints a light system bar (and a contrast scrim)
        // over the black strip.
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
          child: KwBottomNav(currentIndex: _index, onSelected: goToTab),
        ),
      ],
    );
  }
}
