import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/location/device_location.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import 'location_picker_screen.dart';

/// The "where are you right now?" prompt the app opens with.
///
/// Search is measured from `users.latitude/longitude`, so a Thekedar who drove
/// to a different site yesterday would otherwise keep getting yesterday's
/// neighbourhood. Asking on every launch is the other failure mode, so a saved
/// point is trusted for [Session.locationMaxAge] — see [Session.needsLocationUpdate].
///
/// Three ways out, cheapest first: take the phone's fix, confirm the point
/// already on file, or open the full picker. Skipping is always allowed — the
/// old point still searches, and the prompt simply returns on the next open.
abstract final class LocationPrompt {
  /// Guards against a second sheet stacking on the first: the shell asks both
  /// on mount and on every resume, and a resume can fire while the sheet is
  /// still up (the OS location-settings screen is itself a pause/resume).
  static bool _open = false;

  /// Shows the prompt when the location is missing or stale, and returns true
  /// only when a new one was actually saved.
  static Future<bool> maybeShow(BuildContext context) async {
    final session = SessionScope.read(context);
    if (_open || !session.needsLocationUpdate) return false;

    _open = true;
    try {
      final outcome = await showModalBottomSheet<_Outcome>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.white,
        // Wide windows would otherwise stretch the sheet across the whole
        // screen; this keeps it a phone-width card, centred.
        constraints: const BoxConstraints(maxWidth: 520),
        builder: (_) => const _LocationPromptSheet(),
      );

      // The picker is pushed from here rather than from inside the sheet: the
      // sheet's own context is gone the moment it pops, and a route pushed on
      // top of a closing sheet inherits its exit animation.
      if (outcome == _Outcome.pickManually) {
        if (!context.mounted) return false;
        return await LocationPickerScreen.push(context) ?? false;
      }
      return outcome == _Outcome.saved;
    } finally {
      _open = false;
    }
  }

  /// The guard above is process-wide, and it only clears when the sheet closes —
  /// a widget test that tears its tree down with the sheet still up would leak
  /// "already open" into the next test.
  @visibleForTesting
  static void resetForTest() => _open = false;
}

/// How the sheet was closed. [_Outcome.later] and a swipe-down both mean "not
/// now", which is why dismissal maps onto null rather than needing its own case.
enum _Outcome { saved, pickManually }

class _LocationPromptSheet extends StatefulWidget {
  const _LocationPromptSheet();

  @override
  State<_LocationPromptSheet> createState() => _LocationPromptSheetState();
}

class _LocationPromptSheetState extends State<_LocationPromptSheet> {
  bool _locating = false;
  bool _keeping = false;

  /// Shown in place of the subtitle when a fix fails, so the reason sits next to
  /// the button that failed instead of in a snackbar behind the sheet.
  String? _error;
  LocationFailure? _failure;

  bool get _busy => _locating || _keeping;

  /// The point already on the account, if any — what the "this is still right"
  /// shortcut re-confirms.
  GeoPoint? get _existing {
    final user = SessionScope.read(context).user;
    return GeoPoint.tryFrom(user?.latitude, user?.longitude);
  }

  /// Hands the pin to the phone's GPS. A fix that resolved no address is still a
  /// success: coordinates are the part search runs on.
  Future<void> _useCurrentLocation() async {
    if (_busy) return;
    setState(() {
      _locating = true;
      _error = null;
      _failure = null;
    });

    try {
      final found = await DeviceLocationService.current();
      if (!mounted) return;
      // Null address/city are dropped by the repository, so a coordinates-only
      // fix leaves whatever label the account already had rather than blanking
      // the header.
      await _save(found.point, address: found.address, city: found.city);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _failure = e.reason;
        _error = _reason(e.reason);
      });
    } on Object catch (e) {
      // The save itself failed — offline, or a 422 from the profile endpoint.
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = describeError(context, e);
      });
    }
  }

  /// "Still here": re-sends the point already on file so the server re-stamps
  /// `location_updated_at`, which is what buys the next four quiet hours.
  Future<void> _keepExisting() async {
    final point = _existing;
    if (_busy || point == null) return;
    setState(() {
      _keeping = true;
      _error = null;
      _failure = null;
    });

    try {
      await _save(point);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _keeping = false;
        _error = describeError(context, e);
      });
    }
  }

  /// Writes the point through `POST /thekedar/profile` and closes the sheet.
  Future<void> _save(GeoPoint point, {String? address, String? city}) async {
    final session = SessionScope.read(context);
    final updated = await session.repo.updateProfile(
      // Resent unchanged: older deploys mark `name` `required` rather than
      // `sometimes` and 422 a location-only save without it.
      name: session.user?.name,
      address: address,
      city: city,
      latitude: point.lat,
      longitude: point.lng,
    );
    if (!mounted) return;
    // Starts the four-hour clock as well as updating the cached user.
    session.saveLocation(updated);
    Navigator.of(context).pop(_Outcome.saved);
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

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final user = SessionScope.of(context).user;
    final label = user?.address ?? user?.city;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.x4l, Gap.x3l, Gap.x4l, Gap.x4l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: Stagger.wrap(
            step: const Duration(milliseconds: 45),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.toggleOff,
                    borderRadius: Radii.rPill,
                  ),
                ),
              ),
              Gap.v20,
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 21,
                      color: AppColors.black,
                    ),
                  ),
                  Gap.hXl,
                  Expanded(child: Text(s.locationAskTitle, style: AppType.h3)),
                ],
              ),
              Gap.vXl,
              // The failure reason replaces the explainer rather than adding a
              // third line of text to read.
              Text(
                _error ?? s.locationAskSubtitle,
                style: _error == null
                    ? AppType.bodyMuted
                    : AppType.bodyMuted.copyWith(color: AppColors.danger),
              ),
              // Only offered when the OS has a screen that can undo the refusal;
              // sending someone to Settings over a plain timeout is a dead end.
              if (_failure == LocationFailure.serviceOff ||
                  _failure == LocationFailure.deniedForever)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        DeviceLocationService.openSettingsFor(_failure!),
                    child: Text(
                      s.openSettings,
                      style: AppType.buttonSmall.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              Gap.v20,
              KwButton(
                label: s.useCurrentLocation,
                icon: Icons.my_location_rounded,
                size: KwButtonSize.large,
                busy: _locating,
                onPressed: _busy ? null : _useCurrentLocation,
              ),
              Gap.vXl,
              KwButton(
                label: s.locationAskPickOnMap,
                icon: Icons.map_rounded,
                variant: KwButtonVariant.outline,
                onPressed: _busy
                    ? null
                    : () =>
                          Navigator.of(context).pop(_Outcome.pickManually),
              ),
              // "Nothing has changed" is a real answer, and the cheapest one —
              // but only when there is a point to confirm.
              if (label != null && _existing != null) ...[
                Gap.v20,
                _KeepRow(
                  label: label,
                  busy: _keeping,
                  onTap: _busy ? null : _keepExisting,
                ),
              ],
              Gap.vXl,
              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: Text(
                    s.locationAskLater,
                    style: AppType.buttonSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  s.locationAskInterval,
                  textAlign: TextAlign.center,
                  style: AppType.micro,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The confirm-what-we-already-have row: reads as a statement of the current
/// address with a tick, rather than as a third competing button.
class _KeepRow extends StatelessWidget {
  const _KeepRow({required this.label, required this.busy, this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.rMd,
      child: Container(
        padding: const EdgeInsets.all(Gap.xxl),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: Radii.rMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.locationAskKeep, style: AppType.bodyStrong),
                  Gap.vXs,
                  Text(
                    label,
                    style: AppType.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Gap.hXl,
            SizedBox(
              width: 20,
              height: 20,
              child: busy
                  ? const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.black,
                    )
                  : const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.black,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
