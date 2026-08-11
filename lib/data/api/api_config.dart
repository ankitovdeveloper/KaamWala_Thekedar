/// Backend wiring for the Laravel API in `D:\WampServer\www\RoziRoti`
/// (`routes/api.php`, prefix `v1`).
///
/// Override at build time without touching source:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.8:8000/api/v1
/// ```
/// An Android emulator reaches the host machine at `10.0.2.2`, not `127.0.0.1`,
/// which is why the default is expressed as a host that the launcher overrides.
///
/// The default below assumes `php artisan serve`. Served through WampServer's
/// Apache instead, the project sits under a sub-path and the URL becomes
/// `http://localhost/RoziRoti/public/api/v1` — or `10.0.2.2` in place of
/// `localhost` from an emulator.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'https://apps.ovsofts.com/RR/public/api/v1',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// Forces the mock repository even when a base URL is present — handy for
  /// demoing the UI with no server running.
  static const useMocks = bool.fromEnvironment('USE_MOCKS');

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 30);

  /// This build is the Thekedar (contractor) app; the Labour app is a separate
  /// surface behind the same `/v1/auth` endpoints.
  static const role = 'thekedar';

  /// Search needs coordinates. Used for `GET /thekedar/labour?lat=&lng=` only
  /// until the user picks their own point in the location screen, which stores
  /// it on `users.latitude/longitude`.
  static const fallbackLat = 28.4595; // Gurgaon
  static const fallbackLng = 77.0266;
  static const defaultRadiusKm = 25;

  /// Google Maps JS / SDK key, supplied at build time so it never lands in
  /// source control:
  /// ```
  /// flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=AIza...
  /// ```
  /// Empty means "no key configured" — the map falls back to the stylised
  /// canvas rather than showing Google's grey error tiles, which also keeps
  /// widget tests renderable.
  static const mapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get hasMapsKey => mapsApiKey.isNotEmpty;

  /// How often `GET /thekedar/bookings/{id}/track` is polled while a job is
  /// live. Between polls the marker animates to the new position, so this is
  /// a data-freshness knob, not a smoothness one.
  static const trackingPollInterval = Duration(seconds: 4);
}
