import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'core/responsive/responsive.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'data/session.dart';

class KaamWalaApp extends StatefulWidget {
  const KaamWalaApp({super.key, this.session});

  /// Injected by tests and by the mock demo build; production creates its own.
  final Session? session;

  @override
  State<KaamWalaApp> createState() => _KaamWalaAppState();
}

class _KaamWalaAppState extends State<KaamWalaApp> {
  late final Session _session = widget.session ?? Session();
  final _navigatorKey = GlobalKey<NavigatorState>();

  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    if (widget.session == null) _session.restore();
  }

  /// When the server invalidates the token mid-session, drop straight back to
  /// login rather than leaving a screen full of failed requests.
  void _onSessionChanged() {
    final isAuthed = _session.isAuthenticated;
    if (_wasAuthenticated && !isAuthed) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.login,
        (_) => false,
      );
    }
    _wasAuthenticated = isAuthed;
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: _session,
      child: MaterialApp(
        title: 'KaamWala',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.light,
        initialRoute: Routes.login,
        onGenerateRoute: Routes.onGenerateRoute,
        // One place to clamp OS font scaling and stop touch/mouse drag from
        // behaving differently across platforms.
        builder: (context, child) => ClampedTextScale(
          child: ScrollConfiguration(
            behavior: const _AppScrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Lets desktop/web users drag-scroll lists with the mouse, and removes the
/// Android glow in favour of the iOS-style stretch used throughout.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
