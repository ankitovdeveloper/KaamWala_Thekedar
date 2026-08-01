import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

/// Text input whose border animates to brand yellow on focus, matching
/// `.input-field:focus{border-color:var(--yellow)}` in the mockups.
class KwTextField extends StatefulWidget {
  const KwTextField({
    super.key,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  State<KwTextField> createState() => _KwTextFieldState();
}

class _KwTextFieldState extends State<KwTextField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);
  bool _focused = false;

  void _onFocusChange() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.danger
        : _focused
        ? AppColors.yellow
        : AppColors.borderStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          decoration: BoxDecoration(
            color: widget.enabled ? AppColors.white : AppColors.surfaceAlt,
            borderRadius: Radii.rSm,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: _focused && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.yellow.withValues(alpha: 0.28),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (widget.prefix != null) ...[
                const SizedBox(width: Gap.xxl),
                widget.prefix!,
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: widget.textInputAction,
                  style: AppType.bodyStrong.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: AppColors.black,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Gap.x3l,
                      vertical: Gap.xxl,
                    ),
                    hintText: widget.hintText,
                    hintStyle: AppType.body.copyWith(
                      fontSize: 15,
                      color: AppColors.muted.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                widget.suffix!,
                const SizedBox(width: Gap.xxl),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.enter,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: Gap.sm, left: Gap.xs),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      Gap.hXs,
                      Flexible(
                        child: Text(
                          widget.errorText!,
                          style: AppType.micro.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Small caption above a field.
class KwFieldLabel extends StatelessWidget {
  const KwFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Text(text, style: AppType.label),
    );
  }
}

/// Search bar used on the map and in list headers.
class KwSearchBar extends StatelessWidget {
  const KwSearchBar({
    super.key,
    this.hintText = 'Dhundein...',
    this.controller,
    this.onChanged,
    this.trailing,
    this.onTap,
    this.readOnly = false,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: Radii.rSm,
        boxShadow: AppColors.floatingShadow,
      ),
      padding: const EdgeInsets.only(left: Gap.xxl, right: Gap.md),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 19, color: Color(0xFF888888)),
          Gap.hMd,
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              style: AppType.body.copyWith(fontSize: 14),
              cursorColor: AppColors.black,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: Gap.xxl),
                hintText: hintText,
                hintStyle: AppType.body.copyWith(
                  fontSize: 14,
                  color: AppColors.muted.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
