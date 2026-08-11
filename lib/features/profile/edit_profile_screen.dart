import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_field.dart';
import '../../widgets/kw_scaffold.dart';
import '../location/location_picker_screen.dart';
import 'widgets/profile_photo_picker.dart';

/// Edit form behind the Profile screen's "Profile Edit karein" button, backed
/// by `POST /v1/thekedar/profile`.
///
/// Phone number is shown but not editable: it is the account identity and
/// changing it would mean re-running the OTP flow, which this form cannot do.
/// Coordinates are owned by the location picker rather than duplicated here as
/// two number fields nobody can fill in sensibly.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  /// Resolves to the saved user, or null if the form was dismissed.
  static Future<AppUser?> push(BuildContext context, AppUser user) =>
      Navigator.of(context).push<AppUser>(
        MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
      );

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email ?? '');
  late final _city = TextEditingController(text: widget.user.city ?? '');
  late final _address = TextEditingController(text: widget.user.address ?? '');

  bool _saving = false;
  String? _nameError;
  String? _emailError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _city.dispose();
    _address.dispose();
    super.dispose();
  }

  /// Deliberately loose: the server is the authority (`email` + `unique`), and
  /// a strict client-side pattern only ever rejects addresses that work.
  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final s = context.s;

    final name = _name.text.trim();
    final email = _email.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = s.nameRequired);
      return;
    }
    if (email.isNotEmpty && !_emailShape.hasMatch(email)) {
      setState(() => _emailError = s.emailInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _nameError = null;
      _emailError = null;
    });

    try {
      final updated = await context.repo.updateProfile(
        name: name,
        // Empty strings clear the column server-side; sending '' rather than
        // omitting the key is what lets someone remove an email they no
        // longer want on the account.
        email: email,
        city: _city.text.trim(),
        address: _address.text.trim(),
      );
      if (!mounted) return;
      context.session.updateUser(updated);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.profileUpdated)));
      Navigator.of(context).pop(updated);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // A 422 names the offending field; anything else is a snackbar.
        if (e is ApiException) {
          _nameError = e.fieldError('name');
          _emailError = e.fieldError('email');
        }
      });
      if (_nameError == null && _emailError == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(describeError(context, e))));
      }
    }
  }

  Future<void> _pickLocation() async {
    final saved = await LocationPickerScreen.push(context);
    if (saved != true || !mounted) return;

    // The picker writes straight through to the session, so mirror the new
    // values into the open form rather than leaving stale text behind.
    final user = context.session.user;
    if (user == null) return;
    _city.text = user.city ?? '';
    _address.text = user.address ?? '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final user = context.session.user ?? widget.user;

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
                      child: Text(s.editProfileTitle, style: AppType.h2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: ContentWidth(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  Gap.x3l,
                  context.pagePadding,
                  Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: Stagger.wrap(
                    step: const Duration(milliseconds: 45),
                    offset: 14,
                    children: [
                      Center(
                        // Writes through to the session, and this build reads
                        // the user from there — so the new photo appears here
                        // without the form having to track it.
                        child: ProfilePhotoPicker(
                          user: user,
                          initials: initialsOf(
                            _name.text.isEmpty ? user.name : _name.text,
                          ),
                          size: 72,
                          background: AppColors.black,
                          foreground: AppColors.yellow,
                        ),
                      ),
                      Gap.vLg,
                      Center(
                        child: Text(
                          user.fullPhone,
                          style: AppType.caption.copyWith(fontSize: 13),
                        ),
                      ),
                      Gap.v24,
                      KwFieldLabel(s.nameLabel),
                      KwTextField(
                        controller: _name,
                        hintText: s.nameHint,
                        errorText: _nameError,
                        textInputAction: TextInputAction.next,
                        // Keeps the monogram above in step as the name is typed.
                        onChanged: (_) => setState(() => _nameError = null),
                      ),
                      Gap.vLg,
                      KwFieldLabel(s.emailLabel),
                      KwTextField(
                        controller: _email,
                        hintText: s.emailHint,
                        errorText: _emailError,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                      ),
                      Gap.vLg,
                      KwFieldLabel(s.cityLabel),
                      KwTextField(
                        controller: _city,
                        hintText: s.cityHint,
                        textInputAction: TextInputAction.next,
                      ),
                      Gap.vLg,
                      KwFieldLabel(s.addressLabel),
                      KwTextField(
                        controller: _address,
                        hintText: s.profileAddressHint,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                      ),
                      Gap.vLg,
                      KwButton(
                        label: s.pickOnMap,
                        icon: Icons.location_on_outlined,
                        variant: KwButtonVariant.outline,
                        size: KwButtonSize.small,
                        onPressed: _pickLocation,
                      ),
                      Gap.v24,
                      KwButton(
                        label: s.saveChanges,
                        icon: Icons.check_rounded,
                        size: KwButtonSize.large,
                        busy: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
