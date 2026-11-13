import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/referral/install_referrer.dart';
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

/// Thekedar sign-up, backed by `POST /v1/auth/register`.
///
/// Collects the four things the account needs and nothing else: name, mobile,
/// address, and an optional email — plus an optional friend's referral code,
/// pre-filled from the Play Store install referrer when the app was installed
/// through a shared link. It does not create anything — the server
/// only checks the number is free and sends a sign-up OTP. The account is
/// created by `verify-otp`, which is why the [SignupDraft] rides along to the
/// OTP screen instead of being thrown away here.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _referral = TextEditingController();

  bool _busy = false;
  String? _nameError;
  String? _phoneError;
  String? _addressError;
  String? _emailError;
  int _shake = 0;

  /// The Terms tick box. Deliberately not remembered between launches: a box
  /// that arrives already ticked is not consent.
  bool _agreed = false;
  String? _termsError;

  /// Which wording the box is agreeing to, carried through to `verify-otp`
  /// where the account is created. Null while it loads, and for good if the
  /// app is showing its bundled copy — see [LegalDocument.acceptedVersion].
  String? _termsVersion;

  /// Where the friend's code stands with the server. Only [_Referral.invalid]
  /// blocks a submit; anything else goes through and `/auth/register`, which
  /// checks the code again, has the last word.
  _Referral _referralState = _Referral.idle;
  String? _referrerName;
  Timer? _referralDebounce;

  /// Bumped on every edit, so an answer for a code that has since been
  /// changed is dropped instead of painting the wrong verdict.
  int _referralSeq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTermsVersion());
    unawaited(_prefillReferral());
  }

  Future<void> _loadTermsVersion() async {
    final doc = await context.repo.legalDocument(LegalDoc.terms);
    if (mounted) setState(() => _termsVersion = doc.acceptedVersion);
  }

  /// Installed from a friend's link? The Play Store remembers the code; put it
  /// in the field so the friend is credited without anyone typing it.
  Future<void> _prefillReferral() async {
    final code = await InstallReferrer.referralCode();
    if (!mounted || code == null || _referral.text.isNotEmpty) return;
    _referral.text = code;
    unawaited(_checkReferral(code));
  }

  @override
  void dispose() {
    _referralDebounce?.cancel();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _email.dispose();
    _referral.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  String get _referralCode => InstallReferrer.normalize(_referral.text);

  /// Waits for typing to pause, then asks the server whose code it is. Too
  /// short to be a code clears the verdict rather than calling it wrong.
  void _onReferralChanged(String _) {
    _referralDebounce?.cancel();
    _referralSeq++;
    final code = _referralCode;
    setState(() {
      _referralState = _Referral.idle;
      _referrerName = null;
    });
    if (!InstallReferrer.isCode(code)) return;
    _referralDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_checkReferral(code)),
    );
  }

  Future<void> _checkReferral(String code) async {
    final seq = ++_referralSeq;
    setState(() => _referralState = _Referral.checking);
    try {
      final name = await context.repo.validateReferralCode(code);
      if (!mounted || seq != _referralSeq) return;
      setState(() {
        _referralState = _Referral.valid;
        _referrerName = name;
      });
    } on Object catch (e) {
      if (!mounted || seq != _referralSeq) return;
      // Only a 422 means "no such code". No signal is not a verdict — the
      // server checks again on submit.
      final invalid = e is ApiException && e.isValidation;
      setState(
        () => _referralState = invalid ? _Referral.invalid : _Referral.idle,
      );
    }
  }

  /// Everything the server would reject, checked here first so a bad form costs
  /// no round trip. Every failing field is flagged in one pass — flagging only
  /// the first would make the user submit four times to find them all.
  bool _validate() {
    final s = context.s;
    final email = _email.text.trim();

    final nameError = _name.text.trim().isEmpty ? s.nameRequired : null;
    final phoneError = _digits.length != 10 ? s.phoneInvalid : null;
    final addressError = _address.text.trim().isEmpty
        ? s.registerAddressRequired
        : null;
    // Optional, so only a non-empty value can be wrong.
    final emailError = email.isNotEmpty && !_looksLikeEmail(email)
        ? s.emailInvalid
        : null;
    final termsError = _agreed ? null : s.termsRequired;
    // Optional too: blank is fine, a known-bad or malformed code is not.
    final referral = _referralCode;
    final referralOk =
        referral.isEmpty ||
        (InstallReferrer.isCode(referral) &&
            _referralState != _Referral.invalid);

    setState(() {
      _nameError = nameError;
      _phoneError = phoneError;
      _addressError = addressError;
      _emailError = emailError;
      _termsError = termsError;
      if (!referralOk) _referralState = _Referral.invalid;
    });

    final ok =
        nameError == null &&
        phoneError == null &&
        addressError == null &&
        emailError == null &&
        termsError == null &&
        referralOk;
    if (!ok) {
      setState(() => _shake++);
      HapticFeedback.heavyImpact();
    }
    return ok;
  }

  /// Deliberately loose: the server's `email` rule is the real gate, and a
  /// strict client-side pattern only ever rejects addresses that work.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_busy || !_validate()) return;

    setState(() => _busy = true);

    final draft = SignupDraft(
      name: _name.text.trim(),
      phone: _digits,
      address: _address.text.trim(),
      email: _email.text.trim(),
      referralCode: _referralCode.isEmpty ? null : _referralCode,
    );

    try {
      // POST /v1/auth/register — checks the number is free and sends the
      // sign-up OTP. Nothing is stored yet.
      final challenge = await context.repo.register(draft: draft);
      if (!mounted) return;

      setState(() => _busy = false);
      await Navigator.of(context).pushNamed(
        Routes.otp,
        arguments: OtpArgs(
          phone: draft.phone,
          countryCode: challenge.countryCode,
          resendIn: challenge.resendIn,
          debugCode: challenge.debugCode,
          // What makes the OTP screen finish a sign-up rather than a login.
          draft: draft,
          termsVersion: _termsVersion,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();

      // A 422 names the offending field. "Already registered" is the common
      // one and deserves its own message, since the fix is to go and log in.
      final api = e is ApiException ? e : null;
      setState(() {
        _busy = false;
        _shake++;
        _nameError = api?.fieldError('name');
        _phoneError = api?.fieldError('phone') != null
            ? context.s.phoneTaken
            : null;
        _addressError = api?.fieldError('address');
        _emailError = api?.fieldError('email');
        if (api?.fieldError('referral_code') != null) {
          _referralState = _Referral.invalid;
        }
      });

      final flagged =
          _nameError != null ||
          _phoneError != null ||
          _addressError != null ||
          _emailError != null ||
          _referralState == _Referral.invalid;
      if (!flagged) _toast(describeError(context, e));
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
    final compactHeight = context.isShort;

    return KwScaffold(
      headerColor: AppColors.yellow,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ContentWidth(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding + 8,
                    compactHeight ? 16 : 24,
                    context.pagePadding + 8,
                    Gap.x4l,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeSlideIn(from: SlideFrom.left, child: _backRow()),
                      SizedBox(height: compactHeight ? 20 : 28),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: Text(s.registerWelcome, style: AppType.h1),
                      ),
                      Gap.vSm,
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 170),
                        child: Text(
                          s.registerSubtitle,
                          style: AppType.bodyMuted,
                        ),
                      ),
                      SizedBox(height: compactHeight ? 20 : 28),

                      // The form. Shake wraps the whole set so a rejected
                      // submit reads as one event rather than four.
                      Shake(
                        trigger: _shake,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 220),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  KwFieldLabel(s.nameLabel),
                                  KwTextField(
                                    controller: _name,
                                    hintText: s.nameHint,
                                    errorText: _nameError,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => _clear(() {
                                      _nameError = null;
                                    }, _nameError),
                                  ),
                                ],
                              ),
                            ),
                            Gap.vLg,
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 270),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  KwFieldLabel(s.phoneNumber),
                                  _phoneRow(),
                                ],
                              ),
                            ),
                            Gap.vLg,
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 320),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  KwFieldLabel(s.addressLabel),
                                  KwTextField(
                                    controller: _address,
                                    hintText: s.registerAddressHint,
                                    errorText: _addressError,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => _clear(() {
                                      _addressError = null;
                                    }, _addressError),
                                  ),
                                ],
                              ),
                            ),
                            Gap.vLg,
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 370),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  KwFieldLabel(s.emailLabel),
                                  KwTextField(
                                    controller: _email,
                                    hintText: s.emailHint,
                                    errorText: _emailError,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => _clear(() {
                                      _emailError = null;
                                    }, _emailError),
                                  ),
                                ],
                              ),
                            ),
                            Gap.vLg,
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 395),
                              child: _referralField(),
                            ),
                          ],
                        ),
                      ),

                      Gap.v24,
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 420),
                        child: KwButton(
                          label: s.registerSubmit,
                          icon: Icons.arrow_forward_rounded,
                          busy: _busy,
                          onPressed: _submit,
                        ),
                      ),
                      Gap.vXxl,
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 470),
                        child: _loginLine(),
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
                delay: const Duration(milliseconds: 540),
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

  /// Clears one field's error on the next keystroke, without a rebuild when
  /// there was no error to clear.
  void _clear(VoidCallback clear, String? current) {
    if (current != null) setState(clear);
  }

  /// The friend's Share & Earn code, with the server's verdict underneath:
  /// whose code it is, or that it is not one.
  Widget _referralField() {
    final s = context.s;
    final note = switch (_referralState) {
      _Referral.checking => Text(
        s.registerReferralChecking,
        style: AppType.micro.copyWith(color: AppColors.muted),
      ),
      _Referral.valid => Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.successDark,
          ),
          Gap.hXs,
          Flexible(
            child: Text(
              s.registerReferralValid(_referrerName ?? ''),
              style: AppType.micro.copyWith(color: AppColors.successDark),
            ),
          ),
        ],
      ),
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KwFieldLabel(s.registerReferralLabel),
        KwTextField(
          controller: _referral,
          hintText: s.registerReferralHint,
          errorText: _referralState == _Referral.invalid
              ? s.registerReferralInvalid
              : null,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: const [ReferralCodeFormatter()],
          prefix: const Icon(
            Icons.card_giftcard_outlined,
            size: 19,
            color: AppColors.muted,
          ),
          suffix: _referralState == _Referral.valid
              ? const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.success,
                )
              : null,
          onSubmitted: (_) => _submit(),
          onChanged: _onReferralChanged,
        ),
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.enter,
          alignment: Alignment.topLeft,
          child: note == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Gap.sm, left: Gap.xs),
                  child: note,
                ),
        ),
      ],
    );
  }

  Widget _backRow() {
    return Row(
      children: [
        Pressable(
          scale: 0.9,
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 19),
          ),
        ),
        Gap.hLg,
        Text(context.s.registration, style: AppType.h4),
      ],
    );
  }

  Widget _phoneRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country code sits at the same height as the field, error text aside.
        Container(
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
        Gap.hLg,
        Expanded(
          child: KwTextField(
            controller: _phone,
            hintText: context.s.phoneHint,
            keyboardType: TextInputType.phone,
            errorText: _phoneError,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              LengthLimitingTextInputFormatter(11),
              PhoneSpaceFormatter(),
            ],
            onChanged: (_) => _clear(() {
              _phoneError = null;
            }, _phoneError),
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

  /// The way back to Login — the other half of the pair the login screen's
  /// "Naya user? Register karein" line forms.
  Widget _loginLine() {
    final s = context.s;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(s.haveAccountPrompt, style: AppType.caption.copyWith(fontSize: 13)),
        Pressable(
          scale: 0.94,
          // `maybePop`, not a push: Login is the route underneath, so popping
          // gets back to it without stacking a second copy.
          onTap: () => Navigator.of(context).maybePop(),
          child: Text(
            s.loginInstead,
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

/// The referral field's verdict. [idle] covers "blank", "still typing" and
/// "could not check" alike — none of those is a reason to stop a sign-up.
enum _Referral { idle, checking, valid, invalid }
