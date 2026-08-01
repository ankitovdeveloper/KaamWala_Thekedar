/// Backend wiring for the Laravel API in `D:\WampServer\www\RoziRoti`
/// (`routes/api.php`, prefix `v1`).
///
/// Override at build time without touching source:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.8:8000/api/v1
/// ```
/// An Android emulator reaches the host machine at `10.0.2.2`, not `127.0.0.1`,
/// which is why the default is expressed as a host that the launcher overrides.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
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

  /// Search needs coordinates. Until a location plugin is wired in, this is the
  /// origin used for `GET /thekedar/labour?lat=&lng=`.
  static const fallbackLat = 28.4595; // Gurgaon
  static const fallbackLng = 77.0266;
  static const defaultRadiusKm = 25;
}
