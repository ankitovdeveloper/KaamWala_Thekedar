import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/animations/effects.dart';
import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_field.dart';
import '../../widgets/kw_scaffold.dart';
import '../../widgets/kw_terms.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;
  int _shake = 0;

  /// The Terms tick box. Deliberately not remembered between launches: a box
  /// that arrives already ticked is not consent.
  bool _agreed = false;
  String? _termsError;

  /// Which wording the box is agreeing to, sent on with `verify-otp`. Null
  /// while it loads, and for good if the app is showing its bundled copy —
  /// see [LegalDocument.acceptedVersion].
  String? _termsVersion;

  @override
  void initState() {
    super.initState();
    // One small GET, started as the screen opens so the version is in hand
    // long before anyone has finished typing a phone number.
    unawaited(_loadTermsVersion());
  }

  Future<void> _loadTermsVersion() async {
    final doc = await context.repo.legalDocument(LegalDoc.terms);
    if (mounted) setState(() => _termsVersion = doc.acceptedVersion);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();

    if (_digits.length != 10) {
      setState(() {
        _error = context.s.phoneInvalid;
        _shake++;
      });
      HapticFeedback.heavyImpact();
      return;
    }

    if (!_agreed) {
      setState(() => _termsError = context.s.termsRequired);
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    try {
      // POST /v1/auth/send-otp — the server sends the code over SMS/WhatsApp.
      final challenge = await context.repo.sendOtp(phone: _digits);
      if (!mounted) return;

      setState(() => _busy = false);
      await Navigator.of(context).pushNamed(
        Routes.otp,
        arguments: OtpArgs(
          phone: _digits,
          countryCode: challenge.countryCode,
          resendIn: challenge.resendIn,
          debugCode: challenge.debugCode,
          termsVersion: _termsVersion,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // A 422 names the offending field; anything else is a banner message.
        _error = e is ApiException ? e.fieldError('phone') : null;
        _shake++;
      });
      HapticFeedback.heavyImpact();
      if (_error == null) _toast(describeError(context, e));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final compactHeight = context.isShort;
    final s = context.s;

    return KwScaffold(
      headerColor: AppColors.yellow,
      body: SafeArea(
        top: false,
        // The form scrolls; the legal line is a separate bottom slot so it
        // stays pinned without needing IntrinsicHeight + Spacer (which can't
        // survive a landscape viewport shorter than the content).
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ContentWidth(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding + 8,
                    compactHeight ? 20 : 32,
                    context.pagePadding + 8,
                    Gap.x4l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _brand(compactHeight),
                      SizedBox(height: compactHeight ? 24 : 36),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 180),
                        child: Text(s.loginWelcome, style: AppType.h1),
                      ),
                      Gap.vSm,
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 240),
                        child: Text(
                          s.loginSubtitle,
                          style: AppType.bodyMuted,
                        ),
                      ),
                      SizedBox(height: compactHeight ? 20 : 28),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: KwFieldLabel(s.phoneNumber),
                      ),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 340),
                        child: Shake(trigger: _shake, child: _phoneRow()),
                      ),
                      Gap.v16,
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 400),
                        child: KwButton(
                          label: s.sendOtp,
                          icon: Icons.send_rounded,
                          busy: _busy,
                          onPressed: _sendOtp,
                        ),
                      ),
                      Gap.vXxl,
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 450),
                        child: _registerLine(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ContentWidth(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding + 8,
                Gap.md,
                context.pagePadding + 8,
                Gap.x3l,
              ),
              child: FadeSlideIn(
                delay: const Duration(milliseconds: 640),
                child: KwTermsCheck(
                  value: _agreed,
                  errorText: _termsError,
                  onChanged: (v) => setState(() {
                    _agreed = v;
                    if (v) _termsError = null;
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brand(bool compactHeight) {
    final s = context.s;
    return Row(
      children: [
        FadeSlideIn(
          from: SlideFrom.none,
          beginScale: 0.6,
          duration: Motion.lazy,
          curve: Motion.settle,
          child: Floating(
            amplitude: 3,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.yellow,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.yellow.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.handyman_rounded,
                size: 25,
                color: AppColors.black,
              ),
            ),
          ),
        ),
        Gap.hXl,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 90),
                from: SlideFrom.left,
                offset: 12,
                child: Text(s.appName, style: AppType.h3),
              ),
              if (!compactHeight)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  from: SlideFrom.left,
                  offset: 12,
                  child: Text(s.tagline, style: AppType.caption),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phoneRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country code sits at the same height as the field, error text aside.
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.xl,
              vertical: 14.5,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: Radii.rSm,
              border: Border.all(color: AppColors.borderStrong, width: 1.5),
            ),
            child: Text(
              '+91',
              style: AppType.bodyStrong.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Gap.hLg,
        Expanded(
          child: KwTextField(
            controller: _phone,
            hintText: context.s.phoneHint,
            keyboardType: TextInputType.phone,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendOtp(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(11),
              PhoneSpaceFormatter(),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            suffix: AnimatedOpacity(
              duration: Motion.fast,
              opacity: _digits.length == 10 ? 1 : 0,
              child: const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.success,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _registerLine() {
    final s = context.s;
    // Wrap so the prompt and the link stack on a narrow screen or at a large
    // font scale instead of colliding.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(s.newUserPrompt, style: AppType.caption.copyWith(fontSize: 13)),
        Pressable(
          scale: 0.94,
          onTap: () => Navigator.of(context).pushNamed(Routes.register),
          child: Text(
            s.register,
            style: AppType.bodyStrong.copyWith(
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

