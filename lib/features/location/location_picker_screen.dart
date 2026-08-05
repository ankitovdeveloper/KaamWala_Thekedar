import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/async/loadable.dart';
import '../../core/location/device_location.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_field.dart';
import '../../widgets/kw_map.dart';
import '../../widgets/kw_scaffold.dart';

/// Lets the Thekedar set their own search origin.
///
/// Four ways in, in the order people reach for them: hand it to the phone's
/// GPS, tap a saved address, drag the map under the pin, or just type the
/// address. The coordinates are what `GET /thekedar/labour?lat=&lng=` sorts by,
/// and the text is what gets prefilled as the work address when a booking is
/// made — so both are saved together through `POST /thekedar/profile`.
///
/// The GPS route is a convenience, never a requirement: a denied permission, a
/// switched-off radio or a platform with no geocoder all leave the other three
/// routes working, which is why nothing here blocks on it.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  /// Resolves to true when the user saved a new location.
  static Future<bool?> push(BuildContext context) =>
      Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
      );

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _address = TextEditingController();
  final _city = TextEditingController();

  late final Loadable<List<SavedAddress>> _saved = Loadable(
    () => context.repo.addresses(),
  );

  GoogleMapController? _map;
  late GeoPoint _point;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // `read`, not `context.session` — subscribing from initState throws, and
    // this is a one-shot prefill that must not follow later session changes
    // anyway (the fields are the user's to edit from here on).
    final user = SessionScope.read(context).user;
    _address.text = user?.address ?? '';
    _city.text = user?.city ?? '';
    _point = GeoPoint(
      user?.latitude ?? ApiConfig.fallbackLat,
      user?.longitude ?? ApiConfig.fallbackLng,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Saved addresses are a shortcut, not a prerequisite — a failure here
      // just hides that section.
      if (mounted) _saved.load();
    });
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _saved.dispose();
    super.dispose();
  }

  /// The camera target *is* the chosen point — the pin is painted at the centre
  /// of the viewport rather than being a draggable marker, which is both easier
  /// to aim with one thumb and impossible to lose off-screen.
  void _onCameraMove(CameraPosition position) {
    _point = position.target.toGeoPoint();
  }

  void _useSaved(SavedAddress saved) {
    _address.text = saved.address;
    _city.text = saved.city ?? '';

    final point = GeoPoint.tryFrom(saved.latitude, saved.longitude);
    if (point != null) {
      setState(() => _point = point);
      _map?.animateCamera(CameraUpdate.newLatLng(point.toLatLng()));
    } else {
      setState(() {});
    }
  }

  /// Hands the pin to the phone's GPS and, when the platform can resolve it,
  /// fills the text fields from the reverse-geocoded address.
  ///
  /// A fix with no address still counts as a success — the coordinates are what
  /// search runs on — so the pin moves either way and a snackbar asks for the
  /// label instead of throwing the whole attempt away.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      final found = await DeviceLocationService.current();
      if (!mounted) return;

      // Only overwrite what the GPS actually knows: a fix that resolved the
      // city but not the street must not blank out an address already typed.
      if (found.address != null) _address.text = found.address!;
      if (found.city != null) _city.text = found.city!;

      setState(() {
        _point = found.point;
        _locating = false;
      });
      _map?.animateCamera(CameraUpdate.newLatLng(found.point.toLatLng()));

      _toast(
        found.hasLabel ? context.s.gpsLocationFound : context.s.gpsNoAddress,
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      _toast(
        _reason(e.reason),
        // Only offer the shortcut when there is a screen that can fix it —
        // sending someone to Settings over a plain timeout is a dead end.
        action: switch (e.reason) {
          LocationFailure.serviceOff || LocationFailure.deniedForever => () =>
            DeviceLocationService.openSettingsFor(e.reason),
          _ => null,
        },
      );
    }
  }

  String _reason(LocationFailure failure) {
    final s = context.s;
    return switch (failure) {
      LocationFailure.serviceOff => s.gpsServiceOff,
      LocationFailure.denied => s.gpsDenied,
      LocationFailure.deniedForever => s.gpsDeniedForever,
      LocationFailure.unavailable => s.gpsUnavailable,
    };
  }

  void _toast(String message, {VoidCallback? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action == null
              ? null
              : SnackBarAction(
                  label: context.s.openSettings,
                  onPressed: action,
                ),
        ),
      );
  }

  Future<void> _save() async {
    final address = _address.text.trim();
    final city = _city.text.trim();

    // A coordinate with no label leaves the header with nothing to show, so
    // one of the two text fields has to be filled in.
    if (address.isEmpty && city.isEmpty) {
      setState(() => _error = context.s.locationNeedsAddress);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // `name` is `required` on `POST /thekedar/profile`, not `sometimes` — an
      // address-only save is still a full profile update as far as the server
      // is concerned, so resend the name we already hold or it 422s with
      // "The name field is required".
      final updated = await context.repo.updateProfile(
        name: SessionScope.read(context).user?.name,
        address: address.isEmpty ? null : address,
        city: city.isEmpty ? null : city,
        latitude: _point.lat,
        longitude: _point.lng,
      );
      if (!mounted) return;
      context.session.updateUser(updated);
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(describeError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return KwScaffold(
      body: Column(
        children: [
          KwHeader(
            padding: const EdgeInsets.fromLTRB(10, 10, 18, 12),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    color: AppColors.black,
                    tooltip: s.back,
                  ),
                  Expanded(
                    child: FadeSlideIn(
                      from: SlideFrom.left,
                      offset: 12,
                      child: Text(s.locationTitle, style: AppType.h2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                0,
                0,
                0,
                Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                _mapArea(),
                ContentWidth(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    Gap.xxl,
                    context.pagePadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(s.locationSubtitle, style: AppType.bodyMuted),
                      Gap.v20,
                      // Above the fields, because letting the phone fill them
                      // in is the fastest route and should be seen first.
                      KwButton(
                        label: s.useCurrentLocation,
                        icon: Icons.my_location_rounded,
                        variant: KwButtonVariant.outline,
                        busy: _locating,
                        onPressed: _useCurrentLocation,
                      ),
                      Gap.v20,
                      KwFieldLabel(s.addressLabel),
                      KwTextField(
                        controller: _address,
                        hintText: s.profileAddressHint,
                        errorText: _error,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      Gap.vLg,
                      KwFieldLabel(s.cityLabel),
                      KwTextField(
                        controller: _city,
                        hintText: s.cityHint,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                      ),
                      Gap.v24,
                      _savedAddresses(),
                      Gap.v24,
                      KwButton(
                        label: s.useThisLocation,
                        icon: Icons.check_rounded,
                        size: KwButtonSize.large,
                        busy: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapArea() {
    final s = context.s;

    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          Positioned.fill(
            child: KwMap(
              center: _point,
              zoom: 15,
              onMapCreated: (controller) => _map = controller,
              onCameraMove: _onCameraMove,
              fallback: const _NoMapBackdrop(),
            ),
          ),
          // Fixed centre pin. Offset up by half its own height so the point of
          // the pin — not its middle — sits on the camera target.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 44,
                  color: AppColors.black,
                  shadows: [
                    Shadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
          // The my-location control every map app puts here. Same handler as
          // the labelled button below the map — this one is for the people who
          // reach for the map first.
          Positioned(
            right: Gap.xxl,
            top: Gap.xxl,
            child: _MapFab(
              icon: Icons.my_location_rounded,
              tooltip: s.useCurrentLocation,
              busy: _locating,
              onPressed: _useCurrentLocation,
            ),
          ),
          Positioned(
            left: Gap.xxl,
            right: Gap.xxl,
            bottom: Gap.xxl,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.xl,
                  vertical: Gap.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: Radii.rPill,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.floatingShadow,
                ),
                // Doubles as the status line while a fix is in flight — a GPS
                // lock can take a slow ten seconds, and two bare spinners don't
                // say what is being waited on.
                child: Text(
                  _locating
                      ? s.gettingLocation
                      : ApiConfig.hasMapsKey
                      ? s.pickOnMapHint
                      : s.typeAddress,
                  textAlign: TextAlign.center,
                  style: AppType.micro.copyWith(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedAddresses() {
    return ListenableBuilder(
      listenable: _saved,
      builder: (context, _) {
        final rows = _saved.value ?? const <SavedAddress>[];
        // Nothing to offer and nothing to explain — skip the section entirely
        // rather than showing an empty card.
        if (rows.isEmpty) return const SizedBox.shrink();

        final s = context.s;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KwSectionTitle(s.savedAddresses),
            KwMenuCard(
              margin: EdgeInsets.zero,
              children: [
                for (final address in rows)
                  KwMenuRow(
                    icon: address.icon,
                    label: address.label,
                    subtitle: address.line,
                    divider: address != rows.last,
                    trailing: address.isDefault
                        ? KwBadge(label: s.defaultBadge)
                        : null,
                    onTap: () => _useSaved(address),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Round control floating over the map, styled like the hint pill below it so
/// the two read as one layer sitting on the map rather than two widgets.
class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Pressable(
      // Null while busy so a second tap cannot queue another fix.
      onTap: busy ? null : onPressed,
      scale: 0.88,
      semanticLabel: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.floatingShadow,
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.black,
                  ),
                )
              : Icon(icon, size: 20, color: AppColors.black),
        ),
      ),
    ),
  );
}

/// Stand-in for the map when no `GOOGLE_MAPS_API_KEY` is configured. The pin
/// still renders on top of it, so the screen reads the same — the coordinates
/// simply stay where they were and the text fields carry the change.
class _NoMapBackdrop extends StatelessWidget {
  const _NoMapBackdrop();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: AppColors.surfaceAlt,
    child: SizedBox.expand(),
  );
}
