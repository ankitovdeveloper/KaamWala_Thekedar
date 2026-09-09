import 'dart:async';

/// Re-runs [onTick] on a timer while a screen is showing something only
/// somebody else can move.
///
/// Nothing on a booking is this Thekedar's to decide alone: the worker accepts
/// it, sets off for the site, reaches it and signs the kaam off from their own
/// phone, and none of that reaches this app on its own. Reloading when the app
/// comes back from the background covers walking away and returning; this
/// covers *sitting on the screen* while it happens, which is exactly what
/// somebody waiting for "Raaste mein" is doing.
///
/// [sync] is called with whether anything on screen can still change, so the
/// timer runs only as long as there is a reason for it — a list of finished
/// bookings costs nothing.
class LivePoll {
  LivePoll({required this.onTick, required this.interval});

  /// Refetches. Must not throw for anything routine; a failed poll is not news.
  final Future<void> Function() onTick;

  final Duration interval;

  Timer? _timer;
  bool _inFlight = false;
  bool _paused = false;
  bool _wanted = false;
  bool _disposed = false;

  bool get isRunning => _timer != null;

  /// Starts or stops the timer to match [wanted] — "is there still something
  /// here that can change without anybody tapping?". Safe to call on every
  /// rebuild; only a change touches the timer.
  void sync({required bool wanted}) {
    _wanted = wanted;
    _apply();
  }

  /// Backgrounded. Polling a screen nobody is looking at only costs battery,
  /// and the screen reloads on resume anyway.
  void pause() {
    _paused = true;
    _apply();
  }

  void resume() {
    _paused = false;
    _apply();
  }

  void _apply() {
    final shouldRun = _wanted && !_paused && !_disposed;
    if (shouldRun == (_timer != null)) return;

    if (shouldRun) {
      _timer = Timer.periodic(interval, (_) => unawaited(_fire()));
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _fire() async {
    // A slow response must not stack up behind the next tick.
    if (_inFlight || _disposed) return;
    _inFlight = true;

    try {
      await onTick();
    } on Object catch (_) {
      // The screen keeps what it already has and the next tick tries again.
      // Surfacing a dropped poll would put an error on a screen that is
      // otherwise fine.
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
