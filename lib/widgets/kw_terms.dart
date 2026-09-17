import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/animations/pressable.dart';
import '../core/i18n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/models/models.dart';
import '../data/session.dart';
import 'kw_button.dart';

/// The Terms & Conditions gate on the login and register screens: a tick box
/// with the two documents linked inside its label.
///
/// The wording behind those links is not shipped with the app — it is written
/// in the admin panel and fetched from `GET /legal/{slug}`, so legal can reword
/// a clause without a store release. See [LegalSheet].
///
/// The screen owns [value] and disables its button until it is true. Nothing is
/// stored locally: agreeing is a per-sign-in act, and it travels to the server
/// with the OTP verification, which is where the account is actually created.
class KwTermsCheck extends StatelessWidget {
  const KwTermsCheck({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Set when the user tried to carry on without ticking. The row turns red and
  /// says why, rather than the button silently doing nothing.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final bad = errorText != null && !value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The whole row toggles, not just the 22dp box — this is a one-handed
        // app used on site. The two links inside are the only part of it that
        // does something else.
        Pressable(
          scale: 0.99,
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: Motion.fast,
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.xl, Gap.lg),
            decoration: BoxDecoration(
              color: bad ? const Color(0x0DD32F2F) : Colors.transparent,
              borderRadius: Radii.rSm,
              border: Border.all(
                color: bad ? AppColors.danger : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Box(checked: value, bad: bad),
                Gap.hMd,
                Expanded(child: _label(context, s)),
              ],
            ),
          ),
        ),
        if (bad) ...[
          Gap.vXs,
          Padding(
            padding: const EdgeInsets.only(left: Gap.md),
            child: Text(
              errorText!,
              style: AppType.micro.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ],
    );
  }

  /// "Main … Terms & Conditions aur Privacy Policy se sehmat hoon", with the
  /// two document names tappable.
  Widget _label(BuildContext context, AppStrings s) {
    final base = AppType.micro.copyWith(height: 1.6, color: AppColors.muted);
    final link = base.copyWith(
      color: AppColors.black,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: s.termsAgreePrefix),
          _linkSpan(context, s.terms, LegalDoc.terms, link),
          TextSpan(text: s.termsAgreeJoin),
          _linkSpan(context, s.privacyPolicy, LegalDoc.privacy, link),
          TextSpan(text: s.termsAgreeSuffix),
        ],
      ),
    );
  }

  InlineSpan _linkSpan(
    BuildContext context,
    String label,
    LegalDoc doc,
    TextStyle style,
  ) {
    return TextSpan(
      text: label,
      style: style,
      recognizer: TapGestureRecognizer()
        ..onTap = () => LegalSheet.show(context, doc),
    );
  }
}

/// The tick itself — a yellow square that fills in, matching the app's buttons
/// rather than Material's blue default.
class _Box extends StatelessWidget {
  const _Box({required this.checked, required this.bad});

  final bool checked;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.enter,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.yellow : AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked
              ? AppColors.yellowDark
              : (bad ? AppColors.danger : AppColors.borderStrong),
          width: 1.6,
        ),
      ),
      child: AnimatedScale(
        duration: Motion.fast,
        curve: Motion.spring,
        scale: checked ? 1 : 0.4,
        child: AnimatedOpacity(
          duration: Motion.instant,
          opacity: checked ? 1 : 0,
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}

/// One legal document, read in a sheet over whatever screen linked to it.
///
/// Loads from the API on open. The repository never throws here — an old server
/// or no signal yields the copy bundled with the app — so this has a spinner
/// and a result, and no error state to design.
class LegalSheet extends StatefulWidget {
  const LegalSheet({super.key, required this.doc});

  final LegalDoc doc;

  static Future<void> show(BuildContext context, LegalDoc doc) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.pill)),
      ),
      builder: (_) => LegalSheet(doc: doc),
    );
  }

  @override
  State<LegalSheet> createState() => _LegalSheetState();
}

class _LegalSheetState extends State<LegalSheet> {
  late final Future<LegalDocument> _future = context.repo.legalDocument(
    widget.doc,
  );

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => FutureBuilder<LegalDocument>(
        future: _future,
        builder: (context, snapshot) {
          final doc = snapshot.data;

          return Column(
            children: [
              Gap.vMd,
              // Grab handle — the sheet is draggable and long enough that the
              // affordance earns its 4dp.
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.toggleOff,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.x4l,
                  Gap.xl,
                  Gap.lg,
                  Gap.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc?.title ?? s.terms,
                        style: AppType.h3.copyWith(fontSize: 18),
                      ),
                    ),
                    Pressable(
                      scale: 0.88,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.veil06,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: doc == null
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          Gap.x4l,
                          Gap.xl,
                          Gap.x4l,
                          Gap.x6l,
                        ),
                        children: [
                          ..._blocks(doc.body),
                          Gap.v24,
                          Text(
                            s.termsVersion(doc.version),
                            style: AppType.micro.copyWith(
                              color: AppColors.arrow,
                            ),
                          ),
                        ],
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.x4l,
                    Gap.md,
                    Gap.x4l,
                    Gap.md,
                  ),
                  child: KwButton(
                    label: s.closeLabel,
                    variant: KwButtonVariant.outline,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Turns the admin's plain text into paragraphs.
  ///
  /// Blank lines separate blocks. Inside a block, a first line that is numbered
  /// ("3. Payment") or ends in a colon is that block's heading — which is how
  /// the seeded documents are written, and what the admin panel tells whoever
  /// edits them.
  List<Widget> _blocks(String body) {
    final blocks = body
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty);

    final out = <Widget>[];
    for (final block in blocks) {
      final lines = block.split('\n');
      final first = lines.first.trim();
      final isHeading =
          lines.length > 1 &&
          first.length <= 80 &&
          (RegExp(r'^\d+[.)]\s').hasMatch(first) || first.endsWith(':'));

      if (out.isNotEmpty) out.add(Gap.v16);

      if (isHeading) {
        out.add(Text(first, style: AppType.bodyStrong.copyWith(fontSize: 14.5)));
        out.add(Gap.vXs);
        out.add(
          Text(
            lines.skip(1).join('\n').trim(),
            style: AppType.bodyMuted.copyWith(height: 1.65),
          ),
        );
      } else {
        out.add(Text(block, style: AppType.bodyMuted.copyWith(height: 1.65)));
      }
    }
    return out;
  }
}
