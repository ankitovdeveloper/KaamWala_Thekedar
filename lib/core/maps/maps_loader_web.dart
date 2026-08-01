import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Guards against a second widget kicking off a parallel load — every caller
/// awaits the same future.
Future<void>? _pending;

/// Injects the Google Maps JS API with [apiKey] and resolves once it is ready.
///
/// Idempotent: later calls return the first load's future. A failure clears the
/// cache so a retry can try again rather than replaying the same error forever.
Future<void> ensureMapsLoaded(String apiKey) {
  if (apiKey.isEmpty) {
    throw StateError('Google Maps key missing — pass --dart-define');
  }
  return _pending ??= _load(apiKey).catchError((Object e) {
    _pending = null;
    throw e;
  });
}

Future<void> _load(String apiKey) {
  if (_alreadyOnPage()) return Future.value();

  final completer = Completer<void>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..type = 'text/javascript'
    ..async = true
    ..src =
        'https://maps.googleapis.com/maps/api/js'
        '?key=$apiKey&libraries=geometry';

  script.onload = (web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }.toJS;

  // The browser reports a bad key as a successful script load with a console
  // error, so this only fires for a genuinely unreachable script.
  script.onerror = (web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Google Maps script load nahi hua — network check karein'),
      );
    }
  }.toJS;

  web.document.head!.append(script);
  return completer.future;
}

/// True when `window.google.maps` is already defined — e.g. after a hot
/// restart, which keeps the page but rebuilds the Dart side.
bool _alreadyOnPage() {
  if (!globalContext.has('google')) return false;
  final google = globalContext.getProperty<JSObject?>('google'.toJS);
  return google != null && google.has('maps');
}
