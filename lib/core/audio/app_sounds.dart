import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's sound effects.
///
/// One player, reused: creating an [AudioPlayer] per tap leaks a native handle
/// on Android and costs a visible pause on the first play. Everything here is
/// deliberately best-effort — a chime that will not play is never a reason for
/// an action that already succeeded to look like it failed, so every call is
/// swallowed rather than surfaced.
abstract final class AppSounds {
  static AudioPlayer? _player;

  /// Set false to silence the app. The celebration still animates; only the
  /// audio drops out.
  static bool enabled = true;

  /// The success chime behind [KwCelebration]. Generated tone, not a recording,
  /// so it ships as a 73 KB mono WAV that decodes instantly on every platform.
  static const _successAsset = 'audio/success.wav';

  /// Fire-and-forget: callers are in the middle of showing a dialog and must
  /// not wait on an audio device.
  static void success() => unawaited(_play(_successAsset));

  static Future<void> _play(String asset) async {
    if (!enabled) return;

    try {
      final player = _player ??= AudioPlayer()
        // Low latency would keep the clip resident, but it also blocks the
        // player from being reused for a different asset later.
        ..setReleaseMode(ReleaseMode.stop);

      // A celebration can follow another one closely (payment marked, then the
      // worker confirming it). Restarting beats two chimes overlapping.
      await player.stop();
      await player.play(
        AssetSource(asset),
        // Loud enough to be heard over a construction site, quiet enough not to
        // startle someone holding the phone to their ear.
        volume: 0.7,
      );
    } on Object catch (e) {
      // No audio device, a denied autoplay policy on web, a muted phone — none
      // of it is worth telling anybody about.
      debugPrint('AppSounds: could not play $asset ($e)');
    }
  }

  /// Releases the native player. Only worth calling when the app is shutting
  /// down; the player is cheap to keep alive between screens.
  static Future<void> dispose() async {
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}
