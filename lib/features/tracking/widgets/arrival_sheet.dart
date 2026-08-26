import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/animations/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/repositories/kaamwala_repository.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_button.dart';

/// "The worker has reached" — mark the arrival and type the four digits they
/// read out. Posting this is what moves the job to Working.
///
/// The code lives only on the worker's phone, so this sheet cannot validate
/// anything locally beyond the length; the verdict comes from the server, and
/// its message (wrong code, tries left, locked) is shown as it is.
///
/// Returns true when the work was started, so the caller can refresh its poll.
class ArrivalSheet extends StatefulWidget {
  const ArrivalSheet({
    super.key,
    required this.repository,
    required this.bookingId,
    required this.workerName,
    this.gpsArrived = false,
  });

  final KaamWalaRepository repository;
  final int bookingId;
  final String workerName;

  /// Whether GPS has already put the worker on site. Advisory: the code is what
  /// counts, because GPS fails and the kaam cannot wait for it.
  final bool gpsArrived;

  static Future<bool?> show(
    BuildContext context, {
    required KaamWalaRepository repository,
    required int bookingId,
    required String workerName,
    bool gpsArrived = false,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    builder: (_) => ArrivalSheet(
      repository: repository,
      bookingId: bookingId,
      workerName: workerName,
      gpsArrived: gpsArrived,
    ),
  );

  @override
  State<ArrivalSheet> createState() => _ArrivalSheetState();
}

class _ArrivalSheetState extends State<ArrivalSheet> {
  final _code = TextEditingController();
  final _focus = FocusNode();

  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Both of them are standing there waiting — open on the keypad.
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    final s = context.s;

    if (code.length != 4) {
      setState(() => _error = s.arrivalCodeIncomplete);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.confirmArrival(widget.bookingId, code);
      if (!mounted) return;
      // Hold the tick briefly so the Thekedar sees it land before the sheet
      // closes and the timeline moves under them.
      setState(() {
        _busy = false;
        _done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // The backend phrases these ("Code galat hai. 4 koshish bachi hai."),
        // and it is the only party that knows how many tries are left.
        _error = e.message;
        _code.clear();
      });
      _focus.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.s.errorGenericFull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Gap.x4l,
          Gap.x4l,
          Gap.x4l,
          Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: Stagger.wrap(
            step: const Duration(milliseconds: 45),
            children: [
              Text(s.arrivalSheetTitle, style: AppType.h3),
              Gap.vXs,
              Text(
                '${widget.workerName} · ${s.arrivalSheetBody}',
                style: AppType.bodyMuted,
              ),
              Gap.vMd,
              Row(
                children: [
                  Icon(
                    widget.gpsArrived
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    size: 14,
                    color: widget.gpsArrived
                        ? AppColors.successDark
                        : AppColors.muted,
                  ),
                  Gap.hSm,
                  Expanded(
                    child: Text(
                      widget.gpsArrived ? s.arrivalGpsHere : s.arrivalGpsNotHere,
                      style: AppType.caption.copyWith(
                        fontSize: 12,
                        color: widget.gpsArrived
                            ? AppColors.successDark
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              Gap.v24,
              // A plain wide field rather than four boxes: the Thekedar is
              // typing what someone is saying out loud, and one target to hit
              // beats four to tab between.
              TextField(
                controller: _code,
                focusNode: _focus,
                enabled: !_busy && !_done,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofillHints: const [],
                maxLength: 4,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: AppType.h2.copyWith(letterSpacing: 12, fontSize: 30),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _confirm(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '– – – –',
                  hintStyle: AppType.h2.copyWith(
                    letterSpacing: 6,
                    fontSize: 26,
                    color: AppColors.arrow,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                    borderSide: const BorderSide(
                      color: AppColors.black,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              if (_error case final message?) ...[
                Gap.vSm,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                ),
              ],
              Gap.v20,
              KwButton(
                label: _done ? s.arrivalDone : s.arrivalConfirm,
                icon: Icons.check_rounded,
                busy: _busy,
                succeeded: _done,
                onPressed: _busy || _done ? null : _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
