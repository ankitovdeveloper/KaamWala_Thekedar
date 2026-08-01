import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/animations/entrance.dart';
import '../../core/async/loadable.dart';
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

/// Lets the Thekedar set their own search origin by hand.
///
/// Three ways in, in the order people reach for them: tap a saved address,
/// drag the map under the pin, or just type the address. The coordinates are
/// what `GET /thekedar/labour?lat=&lng=` sorts by, and the text is what gets
/// prefilled as the work address when a booking is made — so both are saved
/// together through `POST /thekedar/profile`.
///
/// There is deliberately no "use my GPS" button: that needs a platform
/// location plugin and a runtime permission the app does not ask for yet.
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
  String? _error;

  @override
  void initState() {
    super.initState();

    final user = context.session.user;
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
      final updated = await context.repo.updateProfile(
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(context, e))));
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
                child: Text(
                  ApiConfig.hasMapsKey ? s.pickOnMapHint : s.typeAddress,
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
