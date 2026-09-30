import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';

/// One of the worker's payout destinations in full, shown once it is picked
/// on the Online side of the payment sheet — so the Thekedar can see whose
/// account the money is about to land in before anything moves.
///
/// The account number is always the masked form the backend sends. UPI id and
/// QR go out as they are: those are meant for whoever is paying.
class LabourPayoutDetails extends StatelessWidget {
  const LabourPayoutDetails({
    super.key,
    required this.payout,
    required this.mode,
  });

  final LabourPayout payout;
  final OnlinePayMode mode;

  Future<void> _copyUpi(BuildContext context, String upiId) async {
    await Clipboard.setData(ClipboardData(text: upiId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.s.payoutCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: Radii.rSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...switch (mode) {
            OnlinePayMode.upi => _upi(context),
            OnlinePayMode.qr => _qr(s),
            OnlinePayMode.bank => _bank(s),
          },
          _row(s.payBeneficiary, payout.beneficiaryName),
          _verificationBadge(s),
        ],
      ),
    );
  }

  List<Widget> _upi(BuildContext context) {
    final s = context.s;
    final upiId = payout.upiId;
    if (upiId == null || upiId.isEmpty) return const [];
    return [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.payoutUpiIdLabel, style: AppType.micro),
                Text(upiId, style: AppType.bodyStrong),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _copyUpi(context, upiId),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(s.payoutCopyUpi),
          ),
        ],
      ),
      Gap.vMd,
    ];
  }

  List<Widget> _qr(AppStrings s) {
    final qrUrl = payout.upiQrUrl;
    if (qrUrl == null || qrUrl.isEmpty) return const [];
    return [
      Center(
        child: ClipRRect(
          borderRadius: Radii.rMd,
          child: Image.network(
            qrUrl,
            width: 180,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
      Gap.vMd,
      Text(s.payQrNote, textAlign: TextAlign.center, style: AppType.caption),
      Gap.vMd,
    ];
  }

  List<Widget> _bank(AppStrings s) => [
    _row(s.payoutBankNameLabel, payout.bankName),
    _row(s.payoutAccountHolderLabel, payout.accountHolderName),
    _row(s.payoutAccountNumberLabel, payout.accountNumberMasked),
    _row(s.payoutIfscLabel, payout.ifsc),
  ];

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppType.caption.copyWith(color: AppColors.muted),
            ),
          ),
          Gap.hMd,
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppType.bodyStrong.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationBadge(AppStrings s) {
    final verified = payout.isVerified;
    final color = verified ? AppColors.successDark : AppColors.muted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.info_outline_rounded,
          size: 15,
          color: color,
        ),
        Gap.hXs,
        Text(
          verified ? s.payoutVerifiedBadge : s.payoutUnverifiedBadge,
          style: AppType.micro.copyWith(color: color),
        ),
      ],
    );
  }
}
