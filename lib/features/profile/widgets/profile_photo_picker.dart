import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_async.dart';
import '../../../widgets/kw_common.dart';

/// The user's avatar with a camera badge on it, backed by
/// `POST /thekedar/profile/photo` and `DELETE /thekedar/profile/photo`.
///
/// Tapping opens a sheet with the three things anyone wants here: gallery,
/// camera, and — only once there is something to remove — remove. The reply to
/// either call is a full user record, so the new URL lands in the session and
/// every avatar in the app follows without a refetch.
///
/// Pictures are downscaled and re-encoded by `image_picker` before they leave
/// the device: a modern phone camera produces files several times the server's
/// 5 MB ceiling, and nothing here needs more than a few hundred pixels.
class ProfilePhotoPicker extends StatefulWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.user,
    this.initials,
    this.size = 76,
    this.background,
    this.foreground,
    this.ring,
    this.onChanged,
  });

  final AppUser user;

  /// Overrides the monogram behind the photo. The edit form passes the name
  /// being typed, so the fallback keeps up with the field above it.
  final String? initials;

  final double size;
  final Color? background;
  final Color? foreground;
  final Color? ring;

  /// Fires after the server has confirmed a change, for hosts that hold their
  /// own copy of the user (a loaded profile bundle, a form's controllers).
  final ValueChanged<AppUser>? onChanged;

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    final s = context.s;
    final hasPhoto = widget.user.profilePhotoUrl != null;

    final choice = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.x4l, 0, Gap.x4l, Gap.md),
              child: Text(
                hasPhoto ? s.changePhoto : s.addPhoto,
                style: AppType.h3,
              ),
            ),
            KwMenuRow(
              icon: Icons.photo_library_outlined,
              label: s.photoFromGallery,
              showChevron: false,
              onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
            ),
            KwMenuRow(
              icon: Icons.photo_camera_outlined,
              label: s.photoFromCamera,
              showChevron: false,
              divider: hasPhoto,
              onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
            ),
            if (hasPhoto)
              KwMenuRow(
                icon: Icons.delete_outline_rounded,
                label: s.removePhoto,
                showChevron: false,
                divider: false,
                foreground: AppColors.danger,
                onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
              ),
            Gap.v20,
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case _PhotoAction.gallery:
        await _upload(ImageSource.gallery);
      case _PhotoAction.camera:
        await _upload(ImageSource.camera);
      case _PhotoAction.remove:
        await _remove();
    }
  }

  Future<void> _upload(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        // An avatar is never shown larger than ~150 logical pixels, so 800 is
        // already generous at 3x — and it keeps the upload off a slow network's
        // critical path.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } on Object catch (e) {
      // A cancelled pick returns null; this is a real platform failure — no
      // gallery, no camera, permission refused at the OS level.
      if (mounted) _toast(describeError(context, e));
      return;
    }
    if (picked == null || !mounted) return;

    // Bytes, not a path: on web the XFile is a blob with no filesystem path.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    await _run(
      () => context.repo.updateProfilePhoto(
        bytes: bytes,
        // Only a label for the server's log — Laravel names the stored file
        // itself, from a hash and the type it sniffs out of the bytes.
        filename: picked!.name.isEmpty ? 'photo.jpg' : picked.name,
      ),
      context.s.photoUpdated,
    );
  }

  Future<void> _remove() =>
      _run(() => context.repo.removeProfilePhoto(), context.s.photoRemoved);

  /// Shared tail of both calls: spin, write the reply through to the session,
  /// confirm, and put the error on screen rather than in the console.
  Future<void> _run(
    Future<AppUser> Function() call,
    String confirmation,
  ) async {
    setState(() => _busy = true);

    try {
      final updated = await call();
      if (!mounted) return;
      context.session.updateUser(updated);
      setState(() => _busy = false);
      widget.onChanged?.call(updated);
      _toast(confirmation);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(describeError(context, e));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final user = widget.user;
    final label = user.profilePhotoUrl == null ? s.addPhoto : s.changePhoto;
    // Scales with the avatar, but never below 22 — the badge is the tap target
    // that opens the sheet, and a 76px hero must not set the floor for it.
    final badge = (widget.size * 0.28).clamp(22.0, 32.0);

    return Tooltip(
      message: label,
      child: Pressable(
        onTap: _busy ? null : _open,
        scale: 0.94,
        semanticLabel: label,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            KwAvatar(
              initials: widget.initials ?? user.initials,
              photoUrl: user.profilePhotoUrl,
              size: widget.size,
              background: widget.background,
              foreground: widget.foreground,
              ring: widget.ring,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.floatingShadow,
                ),
                child: Center(
                  child: _busy
                      ? SizedBox(
                          width: badge * 0.5,
                          height: badge * 0.5,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.black,
                          ),
                        )
                      : Icon(
                          Icons.photo_camera_rounded,
                          size: badge * 0.55,
                          color: AppColors.black,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoAction { gallery, camera, remove }
