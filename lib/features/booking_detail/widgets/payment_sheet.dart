import 'package:flutter/material.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/payments/payment_gateway.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/kaamwala_repository.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_async.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_celebration.dart';
import '../../../widgets/kw_common.dart';
import 'payout_details.dart';

/// How the money went — what the caller's celebration says.
enum PaidVia { offline, online }

enum _Side { offline, online }

/// "Payment karein" — opens by itself the moment the kaam is done, and from
/// every "Payment karein" button after that.
///
/// The mode is picked first: **Offline** is cash in hand (the manual mark,
/// which the worker then confirms from their app) and **Online** goes through
/// Razorpay to the UPI id, QR or bank account the worker saved in their own
/// app. Which side is on is the server's call (`can.pay_offline` /
/// `can.pay_online`); which destination is, is what `labour_payout` says the
/// worker has on file and Razorpay has verified.
///
/// Owns every round trip, like the arrival sheet — the errors belong inline,
/// next to the button that caused them. Pops with how it was paid, or null
/// when the Thekedar closed it without paying.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.repository,
    required this.gateway,
    required this.bookingId,
    this.detail,
  });

  final KaamWalaRepository repository;
  final PaymentGateway gateway;
  final int bookingId;

  /// The booking as the caller already has it. Without it — the bookings list
  /// only has the row — the sheet fetches the full record itself, since the
  /// worker's payout details only come with that.
  final BookingDetail? detail;

  static Future<PaidVia?> show(
    BuildContext context, {
    required int bookingId,
    BookingDetail? detail,
  }) {
    final repository = context.repo;
    final gateway = context.payments;
    return showModalBottomSheet<PaidVia>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (_) => PaymentSheet(
        repository: repository,
        gateway: gateway,
        bookingId: bookingId,
        detail: detail,
      ),
    );
  }

  /// The popup once the sheet has closed paid — one wording for every screen
  /// that opens it. Left to the caller so it can refetch first, and the screen
  /// behind the confetti already reads "paid".
  static Future<void> celebrate(
    BuildContext context,
    PaidVia via, {
    required String workerName,
    required int amount,
  }) {
    final s = context.s;
    return KwCelebration.show(
      context,
      title: s.celebratePaymentTitle,
      message: switch (via) {
        PaidVia.offline => s.celebratePaymentBody(workerName),
        PaidVia.online => s.celebrateOnlinePaymentBody(workerName),
      },
      detail: '₹$amount',
      detailIcon: Icons.payments_rounded,
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  BookingDetail? _detail;
  Object? _loadError;

  /// A local copy, so a successful re-verification can light the options up
  /// without refetching the whole booking.
  LabourPayout? _payout;

  _Side? _side;
  OnlinePayMode? _mode;

  bool _busy = false;
  bool _checking = false;
  PaidVia? _done;
  String? _error;

  /// Checkout said yes but the server could not be told. Kept so the retry
  /// re-sends this receipt instead of charging the Thekedar a second time.
  PaymentReceipt? _unconfirmed;

  @override
  void initState() {
    super.initState();
    if (widget.detail case final detail?) {
      _adopt(detail);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final detail = await widget.repository.bookingDetail(widget.bookingId);
      if (!mounted) return;
      // Settled since the caller's row was drawn — the worker took cash on
      // their side, say. Nothing to pay; the caller refreshes on close.
      if (!detail.can.markPayment) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _adopt(detail));
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// Runs from [initState] too, so it must not touch `context`.
  void _adopt(BookingDetail detail) {
    _detail = detail;
    _payout = detail.labourPayout;
    // Preselected only where there is no choice to make.
    if (_offlineOn && !_onlineOn) _side = _Side.offline;
    if (_onlineOn && !_offlineOn) _side = _Side.online;
    _mode = _defaultMode();
  }

  bool get _offlineOn => _detail!.can.payOffline;

  bool get _onlineOn =>
      _detail!.can.payOnline &&
      widget.gateway.isAvailable &&
      (_payout?.hasPaymentMode ?? false);

  /// Why Offline cannot be picked, or null when it can.
  String? _offlineOff(AppStrings s) => _offlineOn ? null : s.payOnlineRequested;

  /// Why Online cannot be picked, or null when it can.
  String? _onlineOff(AppStrings s) {
    if (!_detail!.can.payOnline) return s.payOnlineOff;
    if (!widget.gateway.isAvailable) return s.payOnlineAppOnly;
    if (!(_payout?.hasPaymentMode ?? false)) return s.payNoDetails;
    return null;
  }

  /// The worker's own ask when it can take the money, else the only
  /// destination that can — never a guess between two.
  OnlinePayMode? _defaultMode() {
    final payout = _payout;
    if (payout == null) return null;
    final asked = OnlinePayMode.parse(_detail!.booking.paymentMode);
    if (asked != null && payout.readyFor(asked)) return asked;
    final ready = OnlinePayMode.values.where(payout.readyFor).toList();
    return ready.length == 1 ? ready.single : null;
  }

  /// No switching sides or destinations mid-payment — and not after a
  /// checkout that may already have taken the money.
  bool get _locked => _busy || _done != null || _unconfirmed != null;

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _payOffline() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.markPaymentDone(widget.bookingId);
      await _finish(PaidVia.offline);
    } on ApiException catch (e) {
      _fail(e.message);
    } on Object catch (_) {
      if (mounted) _fail(context.s.errorGenericFull);
    }
  }

  Future<void> _payOnline() async {
    final mode = _mode;
    if (mode == null) return;
    final s = context.s;

    setState(() {
      _busy = true;
      _error = null;
    });

    final PaymentReceipt receipt;
    try {
      receipt =
          _unconfirmed ??
          await widget.gateway.checkout(
            await widget.repository.createPaymentOrder(
              widget.bookingId,
              mode: mode,
            ),
            description:
                '${s.bookingNumber(widget.bookingId)} · ${_detail!.labour.name}',
          );
    } on PaymentCancelled {
      _fail(s.payCancelled);
      return;
    } on PaymentFailed catch (e) {
      _fail(e.message ?? s.payFailed);
      return;
    } on ApiException catch (e) {
      // The server's own words: payout not verified, already paid, ...
      _fail(e.message);
      return;
    } on Object catch (_) {
      _fail(s.errorGenericFull);
      return;
    }

    try {
      await widget.repository.verifyPayment(
        widget.bookingId,
        receipt: receipt,
        mode: mode,
      );
      _unconfirmed = null;
      await _finish(PaidVia.online);
    } on Object catch (e) {
      if (e is ApiException && e.isValidation) {
        // The server looked at the receipt and said no — re-sending it would
        // only get the same answer.
        _unconfirmed = null;
        _fail(e.message);
        return;
      }
      // The money has most likely moved; the server just has not heard, and
      // Razorpay's webhook will settle it there regardless. Charging again is
      // the one outcome this must never allow.
      _unconfirmed = receipt;
      _fail(s.payVerifyPending);
    }
  }

  /// `POST .../labour-payout/verify` — Razorpay re-checks the worker's details
  /// on the spot, for the ones saved but never (or no longer) verified.
  Future<void> _recheck() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final name = await widget.repository.verifyLabourPayout(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _payout = _payout?.copyWith(
          verificationStatus: 'verified',
          beneficiaryName: name,
        );
        _mode ??= _defaultMode();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (_) {
      if (mounted) setState(() => _error = context.s.errorGenericFull);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Holds the tick briefly so it is seen landing before the sheet closes.
  Future<void> _finish(PaidVia via) async {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = via;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) Navigator.of(context).pop(via);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Not while a call is in flight: closing then would drop its answer.
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Gap.x4l,
            Gap.x4l,
            Gap.x4l,
            Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: switch (_detail) {
            final detail? => _content(detail),
            _ => _loading(),
          },
        ),
      ),
    );
  }

  Widget _loading() {
    final error = _loadError;
    if (error == null) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          describeError(context, error),
          textAlign: TextAlign.center,
          style: AppType.bodyMuted,
        ),
        Gap.v16,
        KwButton(
          label: context.s.retry,
          variant: KwButtonVariant.outline,
          onPressed: _load,
        ),
      ],
    );
  }

  Widget _content(BookingDetail detail) {
    final s = context.s;
    final name = detail.labour.name;
    final amount = detail.payment.amount;
    final asked = OnlinePayMode.parse(detail.booking.paymentMode);
    final offlineOff = _offlineOff(s);
    final onlineOff = _onlineOff(s);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(s.payNow, style: AppType.h3)),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.xl,
                vertical: Gap.xs,
              ),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                borderRadius: Radii.rPill,
              ),
              child: Text(
                '₹$amount',
                style: AppType.price.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
        Gap.vXs,
        Text(s.paySheetSubtitle(name, amount), style: AppType.bodyMuted),
        if (asked != null) ...[
          Gap.vMd,
          _note(
            Icons.info_outline_rounded,
            s.payLabourAsked(name, asked.labelIn(s)),
            color: AppColors.pendingText,
          ),
        ],
        Gap.v20,
        Text(s.payChooseMode, style: AppType.label),
        Gap.vMd,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SideCard(
                  icon: Icons.payments_rounded,
                  title: s.payOffline,
                  hint: offlineOff ?? s.payOfflineHint,
                  enabled: offlineOff == null,
                  selected: _side == _Side.offline,
                  onTap: _locked ? null : () => _pick(_Side.offline),
                ),
              ),
              Gap.hXl,
              Expanded(
                child: _SideCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: s.payOnline,
                  hint: onlineOff ?? s.payOnlineHint,
                  enabled: onlineOff == null,
                  selected: _side == _Side.online,
                  onTap: _locked ? null : () => _pick(_Side.online),
                ),
              ),
            ],
          ),
        ),
        ...switch (_side) {
          _Side.offline => _offline(name, amount),
          _Side.online => _online(name, amount),
          null => const <Widget>[],
        },
      ],
    );
  }

  void _pick(_Side side) => setState(() {
    _side = side;
    _error = null;
  });

  List<Widget> _offline(String name, int amount) {
    final s = context.s;
    return [
      Gap.v20,
      Container(
        padding: const EdgeInsets.all(Gap.x3l),
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: Radii.rMd,
        ),
        child: _note(Icons.handshake_outlined, s.payOfflineNote(name)),
      ),
      ..._errorLine(),
      Gap.v20,
      KwButton(
        label: s.payOfflineConfirm(amount),
        icon: Icons.check_rounded,
        busy: _busy,
        succeeded: _done != null,
        onPressed: _locked ? null : _payOffline,
      ),
    ];
  }

  List<Widget> _online(String name, int amount) {
    final s = context.s;
    // The side is only pickable with a payout method on file.
    final payout = _payout!;

    return [
      Gap.v20,
      Text(s.payWhereTo(name), style: AppType.label),
      Gap.vMd,
      for (final mode in OnlinePayMode.values) ...[
        _DestinationTile(
          mode: mode,
          payout: payout,
          selected: _mode == mode,
          onTap: payout.readyFor(mode) && !_locked
              ? () => setState(() {
                  _mode = mode;
                  _error = null;
                })
              : null,
        ),
        Gap.vMd,
      ],
      if (!payout.isVerified)
        Row(
          children: [
            Expanded(
              child: _note(Icons.info_outline_rounded, s.payRecheckNote(name)),
            ),
            TextButton(
              onPressed: _checking || _locked ? null : _recheck,
              child: _checking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.payRecheck, style: AppType.buttonSmall),
            ),
          ],
        ),
      ..._errorLine(),
      Gap.vXl,
      KwButton(
        label: _unconfirmed != null
            ? s.payConfirmAgain
            : s.payOnlineButton(amount),
        icon: Icons.lock_rounded,
        busy: _busy,
        succeeded: _done != null,
        onPressed: _mode == null || _busy || _done != null ? null : _payOnline,
      ),
      Gap.vMd,
      _note(Icons.verified_user_outlined, s.payOnlineNote(name)),
    ];
  }

  List<Widget> _errorLine() => [
    if (_error case final message?) ...[
      Gap.vMd,
      Text(
        message,
        textAlign: TextAlign.center,
        style: AppType.caption.copyWith(
          fontSize: 12.5,
          color: AppColors.danger,
        ),
      ),
    ],
  ];

  Widget _note(IconData icon, String text, {Color color = AppColors.muted}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          Gap.hMd,
          Expanded(
            child: Text(
              text,
              style: AppType.caption.copyWith(color: color, height: 1.4),
            ),
          ),
        ],
      );
}

/// Offline or Online — one of two big tiles, side by side.
class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// What it covers — or, when [enabled] is false, why it is off.
  final String hint;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled ? 1 : 0.5,
        child: KwCard(
          onTap: enabled ? onTap : null,
          color: selected ? AppColors.yellowLight : AppColors.white,
          borderColor: selected ? AppColors.black : AppColors.borderStrong,
          padding: const EdgeInsets.all(Gap.x3l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: AppColors.black),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? AppColors.black : AppColors.arrow,
                  ),
                ],
              ),
              Gap.vMd,
              Text(title, style: AppType.h4),
              Gap.vXs,
              Text(
                hint,
                style: AppType.caption.copyWith(
                  fontSize: 12,
                  color: enabled ? AppColors.muted : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the worker's UPI id / bank account / QR, as a pickable row. Opens
/// out to the full details once picked.
class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.mode,
    required this.payout,
    required this.selected,
    required this.onTap,
  });

  final OnlinePayMode mode;
  final LabourPayout payout;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final offered = payout.offers(mode);
    final ready = payout.readyFor(mode);

    final (IconData icon, String? line) = switch (mode) {
      OnlinePayMode.upi => (Icons.alternate_email_rounded, payout.upiId),
      OnlinePayMode.bank => (
        Icons.account_balance_outlined,
        [
          payout.bankName,
          payout.accountNumberMasked,
        ].whereType<String>().where((v) => v.isNotEmpty).join(' · '),
      ),
      OnlinePayMode.qr => (Icons.qr_code_2_rounded, s.payQrSubtitle),
    };
    final status = !offered
        ? s.payNotAdded
        : !ready
        ? s.payNotVerified
        : null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: ready,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: ready ? 1 : 0.55,
        child: KwCard(
          onTap: onTap,
          color: selected ? AppColors.yellowLight : AppColors.white,
          borderColor: selected ? AppColors.black : AppColors.borderStrong,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.x3l,
            vertical: Gap.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.yellow : AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: AppColors.black),
                  ),
                  Gap.hXl,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mode.labelIn(s), style: AppType.bodyStrong),
                        if (offered && line != null && line.isNotEmpty)
                          Text(
                            line,
                            style: AppType.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Gap.hMd,
                  if (status != null)
                    KwPill(label: status, dense: true)
                  else
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected ? AppColors.black : AppColors.arrow,
                    ),
                ],
              ),
              // The whole of it only once picked: enough to check it is the
              // right person's account before any money moves.
              AnimatedSize(
                duration: Motion.fast,
                curve: Motion.enter,
                alignment: Alignment.topCenter,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(top: Gap.xl),
                        child: LabourPayoutDetails(payout: payout, mode: mode),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
