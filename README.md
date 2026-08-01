# KaamWala — Thekedar App

Flutter client for the contractor ("thekedar") side of KaamWala: find nearby
labour on a map, book them by the day, track jobs, review the work.

Built from the HTML mockups in `screens.zip` and wired to the Laravel API in
`D:\WampServer\www\RoziRoti` (`routes/api.php`, prefix `v1`).

---

## Running it

```bash
flutter pub get

# Against a local Laravel server (php artisan serve)
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

# Android emulator — the host machine is 10.0.2.2, not 127.0.0.1
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical device on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://192.168.1.8:8000/api/v1

# No backend — seeded demo data, every screen fully navigable
flutter run --dart-define=USE_MOCKS=true
```

Both flags live in [api_config.dart](lib/data/api/api_config.dart).

### Web / CORS

`flutter run -d chrome` serves from a random port, so Laravel must allow it.
In `config/cors.php` set `'allowed_origins' => ['*']` for local development, or
run on a device/emulator instead.

---

## Architecture

```
lib/
  core/
    animations/     entrance, pressable, effects — the motion vocabulary
    async/          Loadable<T>: one remote value + loading/error state
    responsive/     breakpoints, ContentWidth, text-scale clamping
    router/         named routes + per-route transitions
    theme/          colours, type ramp, spacing, Motion constants
  data/
    api/            ApiClient (envelope + errors), ApiConfig, ApiException
    models/         wire models; field names mirror the PHP models
    repositories/   KaamWalaRepository ← ApiRepository | MockRepository
    session.dart    token persistence, current user, SessionScope
  features/         one folder per screen
  widgets/          the shared component kit (Kw*)
```

**Repository swap.** Screens depend on the `KaamWalaRepository` interface, never
on HTTP. `ApiRepository` talks to Laravel; `MockRepository` serves seeded data.
That's what lets `USE_MOCKS=true` work and what keeps widget tests offline and
fast.

**Envelope.** Every endpoint answers with `App\Traits\ApiResponse`:

```json
{ "success": true,  "message": "...", "data": { ... } }
{ "success": false, "message": "...", "errors": { "phone": ["..."] } }
```

`ApiClient` unwraps `data` and turns anything else into a typed
`ApiException` — including 401 (fires `onUnauthorized`, which clears the
session and bounces to login), 422 (field-keyed validation errors), network
failures and non-JSON bodies (a PHP fatal or an HTML 404 page).

**Auth.** Sanctum bearer token, persisted in `shared_preferences`. On cold start
`Session.restore()` replays the token against `GET /me`; if that call fails
because the device is offline it keeps the cached user rather than forcing a
re-login.

---

## Endpoints in use

| Screen | Call |
| --- | --- |
| Login | `POST /auth/send-otp` |
| OTP | `POST /auth/verify-otp`, `POST /auth/resend-otp` |
| Search | `GET /thekedar/labour?lat&lng&radius&skill_id&q&sort`, `GET /skills` |
| Labour detail | `GET /thekedar/labour/{id}`, `POST /thekedar/saved-labours/{id}/toggle` |
| Book Now | `POST /thekedar/bookings` |
| Bookings | `GET /thekedar/bookings?tab=`, `POST .../cancel`, `POST .../review` |
| Profile | `GET /thekedar/profile` |
| Account | `GET /thekedar/account`, `PUT /thekedar/account/preferences` |
| Logout | `POST /auth/logout` |

### Gaps worth knowing

- **Location is not yet device-derived.** Search needs `lat`/`lng`; the app uses
  the signed-in user's saved coordinates and falls back to the Gurgaon centre in
  `ApiConfig`. Wiring a location plugin means changing `_origin` in
  [search_screen.dart](lib/features/search/search_screen.dart) and nothing else.
- **The max-rate filter is client-side.** `GET /thekedar/labour` has no rate
  parameter, so the cap is applied after the response — see
  `LabourFilters.applyLocal`. Adding a server-side `max_rate` would make it
  correct across pagination.
- **Search only returns on-duty labour.** `is_on_duty = true` is hardcoded in
  `LabourSearchController::index`, so the "Sirf available" toggle is a no-op
  against the real API (it still works against mocks).
- **Results are not paginated in the UI.** The endpoint returns 20 per page;
  the app reads page 1. Infinite scroll needs `?page=` plumbing.
- **`thekedar/statistics` counts active bookings as `status = 'confirmed'`,**
  but `Booking::STATUS_ACCEPTED` is `'accepted'` — so that field always reads 0.
  The app therefore uses `GET /thekedar/profile` → `stats`, which is correct.
  Worth fixing in `StatisticsController` on the backend.

---

## Design system

Lifted from the mockups' CSS variables — one source of truth in
[app_colors.dart](lib/core/theme/app_colors.dart) and
[app_typography.dart](lib/core/theme/app_typography.dart).

Yellow `#FFD600` · black `#111111` · canvas `#F7F7F7` · radii 14 / 8.

All motion pulls its duration and curve from `Motion` in
[app_theme.dart](lib/core/theme/app_theme.dart), so the whole app moves with one
personality. Decorative loops (map pulse, floating icons, the pending-badge
breath) stop when the OS asks for reduced motion.

### Responsive behaviour

| Width | Layout |
| --- | --- |
| < 600 | Bottom nav, single column |
| ≥ 600 | Side rail replaces the bottom bar |
| ≥ 1000 | Search becomes two-pane: list left, detail right |
| ≥ 1180 | Rail expands with labels |

Content is width-capped and centred past 520pt so line lengths stay readable on
a desktop monitor, and OS font scaling is clamped to 0.85–1.3.

---

## Tests

```bash
flutter test
```

124 tests in three files:

- [api_repository_test.dart](test/api_repository_test.dart) — parses real
  Laravel payload shapes through a fake HTTP client: the envelope, 401/422/parse
  errors, the paginator wrapper, MySQL quirks (`"450"` as a string, tinyint
  `1` for booleans, `"10:00:00"` times, ISO-serialised `date` casts), and the
  exact request bodies sent back.
- [responsive_test.dart](test/responsive_test.dart) — renders every screen at 8
  viewports (320px phone → 1920px desktop) plus 1.3× font scale. A `RenderFlex`
  overflow fails the test, so this is a real layout check rather than a smoke
  test.
- [widget_test.dart](test/widget_test.dart) — flows: login validation, OTP →
  signed in → Search, search filtering, booking tabs, nav and the rail swap.
