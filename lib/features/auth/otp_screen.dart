import 'dart:async';

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
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_scaffold.dart';

/// What `POST /v1/auth/send-otp` told us, carried into the verify step.
class OtpArgs {
  const OtpArgs({
    required this.phone,
    this.countryCode = '+91',
    this.resendIn = 30,
    this.debugCode,
  });

  /// Bare digits — the format the API expects back on verify.
  final String phone;
  final String countryCode;

  /// Cool-down before `resend-otp` will be accepted (the server 429s early).
  final int resendIn;

  /// Debug builds echo the code back; we prefill it so QA isn't hunting logs.
  final String? debugCode;
}

/// Six-box OTP entry backed by `POST /v1/auth/verify-otp`.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _length = 6;

  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _nodes = List.generate(_length, (_) => FocusNode());

  Timer? _ticker;
  late int _secondsLeft = widget.args.resendIn;
  bool _busy = false;
  bool _verified = false;
  bool _invalid = false;
  String? _errorText;
  int _shake = 0;

  String get _code => _controllers.map((c) => c.text).join();
  bool get _complete => _code.length == _length;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.args.resendIn);

    final debug = widget.args.debugCode;
    if (debug != null && debug.length == _length) {
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = debug[i];
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Land the caret on the first empty box.
      final next = _controllers.indexWhere((c) => c.text.isEmpty);
      _nodes[next == -1 ? _length - 1 : next].requestFocus();
    });
  }

  void _startCountdown(int seconds) {
    _ticker?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;

    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onDigit(int index, String value) {
    if (_invalid) setState(() => _invalid = false);

    // Handle a full code pasted into one box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      _nodes[(digits.length.clamp(0, _length - 1))].requestFocus();
      setState(() {});
      if (_complete) _verify();
      return;
    }

    setState(() {});

    if (value.isNotEmpty && index < _length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isNotEmpty && index == _length - 1) {
      _nodes[index].unfocus();
      if (_complete) _verify();
    }
  }

  /// Backspace on an empty box steps back to the previous one.
  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _nodes[index - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _verify() async {
    if (!_complete || _busy || _verified) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _errorText = null;
    });

    final session = context.session;

    try {
      // POST /v1/auth/verify-otp — creates the account on first login and
      // returns the Sanctum token.
      final result = await session.repo.verifyOtp(
        phone: widget.args.phone,
        otp: _code,
        countryCode: widget.args.countryCode,
      );
      await session.signIn(result);
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      setState(() {
        _busy = false;
        _verified = true;
      });

      // Let the tick finish drawing before leaving.
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (_) => false);
    } on Object catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _invalid = true;
        _shake++;
        _errorText = e is ApiException && e.isValidation
            ? e.message
            : describeError(context, e);
      });
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _busy) return;
    HapticFeedback.selectionClick();

    for (final c in _controllers) {
      c.clear();
    }
    setState(() {
      _invalid = false;
      _errorText = null;
    });
    _nodes[0].requestFocus();

    try {
      final challenge = await context.repo.resendOtp(
        phone: widget.args.phone,
        countryCode: widget.args.countryCode,
      );
      if (!mounted) return;
      _startCountdown(challenge.resendIn);
      _toast(context.s.otpResent);
    } on Object catch (e) {
      if (!mounted) return;
      // A 429 means the cool-down hasn't elapsed; restart the timer locally.
      if (e is ApiException && e.statusCode == 429) {
        _startCountdown(widget.args.resendIn);
      }
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
    return KwScaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ContentWidth(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding + 8,
                  Gap.x5l,
                  context.pagePadding + 8,
                  Gap.x4l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(from: SlideFrom.left, child: _backRow()),
                    Gap.v28,
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: Text(s.otpSentLine, style: AppType.bodyMuted),
                    ),
                    Gap.vSm,
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.smartphone_rounded,
                            size: 18,
                            color: AppColors.black,
                          ),
                          Gap.hSm,
                          Flexible(
                            child: Text(
                              '${widget.args.countryCode} ${widget.args.phone}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.bodyStrong.copyWith(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap.v32,
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 180),
                      child: Shake(trigger: _shake, child: _otpRow()),
                    ),
                    // Server-side rejection ("OTP galat hai", "OTP expire ho
                    // gaya") shown under the boxes.
                    AnimatedSize(
                      duration: Motion.fast,
                      curve: Motion.enter,
                      child: _errorText == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: Gap.lg),
                              child: Text(
                                _errorText!,
                                textAlign: TextAlign.center,
                                style: AppType.micro.copyWith(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                    Gap.vLg,
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 240),
                      child: _resendRow(),
                    ),
                    Gap.v28,
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: KwButton(
                        label: s.otpVerify,
                        icon: Icons.verified_user_rounded,
                        busy: _busy,
                        succeeded: _verified,
                        onPressed: _complete ? _verify : null,
                      ),
                    ),
                    Gap.v20,
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 360),
                      child: _infoBox(),
                    ),
                  ],
                ),
              ),
            ),
            // Success overlay — dims the form and draws a tick before routing.
            IgnorePointer(
              child: AnimatedOpacity(
                duration: Motion.normal,
                opacity: _verified ? 1 : 0,
                child: ColoredBox(
                  color: AppColors.canvas.withValues(alpha: 0.86),
                  child: SizedBox.expand(
                    child: _verified
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const DrawnCheck(size: 72),
                              Gap.v20,
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 260),
                                child: Text(s.otpLoggedIn, style: AppType.h3),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backRow() {
    return Row(
      children: [
        KwIconButton(
          icon: Icons.arrow_back_rounded,
          background: AppColors.veil06,
          iconSize: 20,
          tooltip: context.s.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Gap.hXl,
        Expanded(
          child: Text(
            context.s.otpTitle,
            style: AppType.h3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _otpRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Give up the gap before shrinking the boxes — a tight row of
        // readable boxes beats a roomy row of cramped ones.
        var gap = Gap.xl;
        var boxWidth = (constraints.maxWidth - gap * (_length - 1)) / _length;
        if (boxWidth < 40) {
          gap = Gap.sm;
          boxWidth = (constraints.maxWidth - gap * (_length - 1)) / _length;
        }
        boxWidth = boxWidth.clamp(30.0, 52.0);
        final boxHeight = boxWidth * 1.13;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _OtpBox(
                controller: _controllers[i],
                focusNode: _nodes[i],
                width: boxWidth,
                height: boxHeight,
                invalid: _invalid,
                onChanged: (v) => _onDigit(i, v),
                onKey: (event) => _onKey(i, event),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _resendRow() {
    final s = context.s;
    final canResend = _secondsLeft == 0;
    final mm = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Center(
      child: SwapIn(
        child: canResend
            ? Pressable(
                key: const ValueKey('resend'),
                scale: 0.94,
                onTap: _resend,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: AppColors.black,
                    ),
                    Gap.hXs,
                    Text(
                      s.otpResend,
                      style: AppType.bodyStrong.copyWith(
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                key: const ValueKey('countdown'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.otpResendIn,
                    style: AppType.caption.copyWith(fontSize: 13),
                  ),
                  // Fixed-width so the row doesn't shuffle as digits change.
                  Text(
                    '$mm:$ss',
                    style: AppType.bodyStrong.copyWith(
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xxl,
        vertical: Gap.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.12),
        borderRadius: Radii.rSm,
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.black,
          ),
          Gap.hMd,
          Expanded(
            child: Text(
              context.s.otpInfo,
              style: AppType.body.copyWith(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single OTP cell. Fills yellow the moment it has a digit and pops slightly
/// as that happens, so progress is felt as much as seen.
class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.width,
    required this.height,
    required this.invalid,
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double width;
  final double height;
  final bool invalid;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent) onKey;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_sync);
    widget.focusNode.onKeyEvent = (_, event) => widget.onKey(event);
  }

  void _sync() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;

    final border = widget.invalid
        ? AppColors.danger
        : filled
        ? AppColors.yellow
        : _focused
        ? AppColors.yellow
        : AppColors.borderStrong;

    final background = widget.invalid
        ? AppColors.danger.withValues(alpha: 0.08)
        : filled
        ? AppColors.yellow
        : AppColors.white;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: filled ? 1 : 0, end: filled ? 1 : 0),
      duration: Motion.normal,
      curve: Motion.spring,
      builder: (context, t, child) =>
          Transform.scale(scale: 1 + 0.07 * t, child: child),
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: background,
          borderRadius: Radii.rSm,
          border: Border.all(color: border, width: 2),
          boxShadow: _focused && !filled
              ? [
                  BoxShadow(
                    color: AppColors.yellow.withValues(alpha: 0.3),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: AppType.otpDigit,
          cursorColor: AppColors.black,
          showCursor: false,
          // Six separate one-char fields would normally break OS autofill;
          // this keeps the SMS-code hint working on both platforms.
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
