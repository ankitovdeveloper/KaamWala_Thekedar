import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/reward_models.dart';
import '../../data/session.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_field.dart';

/// "Where should we send it?" — the delivery details for a physical reward.
///
/// The sheet makes the claim call itself and closes with `true` once the server
/// has accepted it, so a refusal (already claimed, a pincode the server will
/// not take) stays on screen next to the field that can fix it.
class ClaimRewardSheet extends StatefulWidget {
  const ClaimRewardSheet({
    super.key,
    required this.userRewardId,
    required this.rewardName,
  });

  final int userRewardId;
  final String rewardName;

  /// Resolves to true when the claim went through.
  static Future<bool> show(
    BuildContext context, {
    required int userRewardId,
    required String rewardName,
  }) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (_) =>
          ClaimRewardSheet(userRewardId: userRewardId, rewardName: rewardName),
    );
    return done == true;
  }

  @override
  State<ClaimRewardSheet> createState() => _ClaimRewardSheetState();
}

class _ClaimRewardSheetState extends State<ClaimRewardSheet> {
  static final _phoneRule = RegExp(r'^[0-9]{10,15}$');
  static final _pincodeRule = RegExp(r'^[0-9]{6}$');

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();

  bool _busy = false;

  /// Per-field messages, keyed by the form field (not the API's name for it).
  final Map<String, String> _errors = {};

  /// Anything the server said that no single field owns.
  String? _banner;

  @override
  void initState() {
    super.initState();
    // The Thekedar's own details are almost always the right ones; they only
    // have to type the address.
    final user = SessionScope.read(context).user;
    if (user != null) {
      _name.text = user.name.trim();
      _phone.text = user.phone.replaceAll(RegExp(r'\D'), '');
      _city.text = (user.city ?? '').trim();
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _city, _state, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills [_errors] and says whether the form is fit to send.
  bool _validate() {
    final s = context.s;
    String? required(TextEditingController c) =>
        c.text.trim().isEmpty ? s.claimRequired : null;

    final found = <String, String?>{
      'name': required(_name),
      'phone': _phoneRule.hasMatch(_phone.text.trim()) ? null : s.claimBadPhone,
      'address': required(_address),
      'city': required(_city),
      'state': required(_state),
      'pincode': _pincodeRule.hasMatch(_pincode.text.trim())
          ? null
          : s.claimBadPincode,
    };

    setState(() {
      _errors
        ..clear()
        ..addAll({
          for (final e in found.entries)
            if (e.value != null) e.key: e.value!,
        });
      _banner = null;
    });
    return _errors.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _busy = true);

    try {
      await context.repo.claimReward(
        widget.userRewardId,
        ClaimDetails(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          city: _city.text.trim(),
          state: _state.text.trim(),
          pincode: _pincode.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showServerError(e);
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = context.s.errorGenericFull;
      });
    }
  }

  /// A 422 carries `errors: {field: [message]}`. The ones that name a field of
  /// this form go under that field; the rest — "already claimed" above all —
  /// go in the banner.
  void _showServerError(ApiException e) {
    // The API's field names, mapped onto this form's.
    const fields = {
      'claim_name': 'name',
      'claim_phone': 'phone',
      'delivery_address': 'address',
      'city': 'city',
      'state': 'state',
      'pincode': 'pincode',
    };
    final flagged = {
      for (final entry in fields.entries)
        entry.value: ?e.fieldError(entry.key),
    };

    setState(() {
      _busy = false;
      _errors
        ..clear()
        ..addAll(flagged);
      _banner = flagged.isEmpty ? e.userMessageIn(context.s) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Gap.x4l,
          0,
          Gap.x4l,
          Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.claimTitle, style: AppType.h3),
            Gap.vXs,
            Text(s.claimSubtitle(widget.rewardName), style: AppType.bodyMuted),
            Gap.v20,
            _field(
              label: s.nameLabel,
              controller: _name,
              errorKey: 'name',
              icon: Icons.person_outline_rounded,
              caps: TextCapitalization.words,
              limit: 100,
            ),
            _field(
              label: s.phoneNumber,
              controller: _phone,
              errorKey: 'phone',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              digitsOnly: true,
              limit: 15,
            ),
            _field(
              label: s.addressLabel,
              controller: _address,
              errorKey: 'address',
              hint: s.claimAddressHint,
              icon: Icons.home_outlined,
              caps: TextCapitalization.sentences,
              limit: 255,
              lines: 2,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    label: s.cityLabel,
                    controller: _city,
                    errorKey: 'city',
                    icon: Icons.location_city_outlined,
                    caps: TextCapitalization.words,
                    limit: 100,
                  ),
                ),
                Gap.hLg,
                Expanded(
                  child: _field(
                    label: s.claimState,
                    controller: _state,
                    errorKey: 'state',
                    icon: Icons.map_outlined,
                    caps: TextCapitalization.words,
                    limit: 100,
                  ),
                ),
              ],
            ),
            _field(
              label: s.claimPincode,
              controller: _pincode,
              errorKey: 'pincode',
              icon: Icons.pin_drop_outlined,
              keyboard: TextInputType.number,
              digitsOnly: true,
              limit: 6,
              action: TextInputAction.done,
            ),
            if (_banner case final message?) ...[
              _Banner(message: message),
              Gap.vXl,
            ],
            KwButton(
              label: _busy ? s.claimSubmitting : s.claimSubmit,
              icon: _busy ? null : Icons.card_giftcard_rounded,
              busy: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String errorKey,
    required IconData icon,
    String? hint,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
    bool digitsOnly = false,
    int limit = 100,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KwFieldLabel(label),
          KwTextField(
            controller: controller,
            enabled: !_busy,
            hintText: hint,
            keyboardType: keyboard,
            textCapitalization: caps,
            textInputAction: action,
            minLines: lines,
            maxLines: lines,
            inputFormatters: [
              if (digitsOnly) FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(limit),
            ],
            prefix: Icon(icon, size: 19, color: AppColors.muted),
            errorText: _errors[errorKey],
            // Typing is the fix for a complaint, so it clears it.
            onChanged: (_) {
              if (_errors.containsKey(errorKey)) {
                setState(() => _errors.remove(errorKey));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xl,
        vertical: Gap.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: Radii.rSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.danger,
          ),
          Gap.hMd,
          Expanded(
            child: Text(
              message,
              style: AppType.caption.copyWith(
                fontSize: 12.5,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
