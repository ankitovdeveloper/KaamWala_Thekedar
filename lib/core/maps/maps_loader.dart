/// Makes the Google Maps SDK usable before the first map widget is built.
///
/// On web the JS API has to be on the page before `google_maps_flutter_web`
/// creates a map, and the key only exists as a `--dart-define` at that point —
/// so it is injected at runtime rather than hardcoded into `web/index.html`.
/// On Android/iOS the native SDK reads its key from the manifest/plist and
/// there is nothing to do, which is what the stub implementation reflects.
library;

export 'maps_loader_stub.dart'
    if (dart.library.js_interop) 'maps_loader_web.dart';
