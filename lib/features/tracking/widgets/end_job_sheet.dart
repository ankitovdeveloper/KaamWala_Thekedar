import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/kaamwala_repository.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_button.dart';

/// "Stop this kaam" — pick a reason, confirm.
///
/// One reason per full-width row rather than a wrap of chips: the labels are
/// whole Hinglish sentences, and a target the width of the sheet is easier to hit
/// than a chip half a word wide. `other` is the only code that demands typing,
/// which is exactly the case where the list had nothing to offer.
///
/// The list comes from the backend so a reworded reason needs no release; the
/// fallback below is used when that call fails, and its codes must stay valid.
///
/// Returns true when the job was stopped, so the caller can refresh its poll.
class EndJobSheet extends StatefulWidget {
  const EndJobSheet({
    super.key,
    required this.repository,
    required this.bookingId,
    required this.workerName,
  });

  final KaamWalaRepository repository;
  final int bookingId;
  final String workerName;

  /// Codes must match `Booking::THEKEDAR_END_REASONS` on the API.
  static const fallback = <EndReason>[
    EndReason(code: 'worker_absent', label: 'Kaam wala aaya hi nahi'),
    EndReason(code: 'worker_late', label: 'Bahut late ho gaya'),
    EndReason(code: 'work_quality', label: 'Kaam theek se nahi ho raha'),
    EndReason(code: 'not_needed', label: 'Ab is kaam ki zarurat nahi'),
    EndReason(code: 'rate_dispute', label: 'Rate par baat nahi bani'),
    EndReason(code: 'misbehaviour', label: 'Vyavhaar theek nahi tha'),
    EndReason(code: 'other', label: 'Koi aur wajah', needsNote: true),
  ];

  static Future<bool?> show(
    BuildContext context, {
    required KaamWalaRepository repository,
    required int bookingId,
    required String workerName,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    builder: (_) => EndJobSheet(
      repository: repository,
      bookingId: bookingId,
      workerName: workerName,
    ),
  );

  @override
  State<EndJobSheet> createState() => _EndJobSheetState();
}

class _EndJobSheetState extends State<EndJobSheet> {
  final _note = TextEditingController();

  List<EndReason> _reasons = EndJobSheet.fallback;
  EndReason? _picked;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReasons();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Renders the fallback immediately and swaps in the served list if it lands —
  /// a spinner in front of the reasons helps nobody at this moment.
  Future<void> _loadReasons() async {
    try {
      final served = await widget.repository.endReasons();
      if (mounted && served.isNotEmpty) setState(() => _reasons = served);
    } catch (_) {/* the fallback stands */}
  }

  Future<void> _submit() async {
    final picked = _picked;
    final s = context.s;

    if (picked == null) {
      setState(() => _error = s.endJobPickReason);
      return;
    }

    final note = _note.text.trim();
    if (picked.needsNote && note.isEmpty) {
      setState(() => _error = s.endJobNoteHint);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.repository.terminateJob(
        widget.bookingId,
        reasonCode: picked.code,
        note: note,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.s.endJobFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final picked = _picked;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4l,
                Gap.x4l,
                Gap.x4l,
                Gap.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.endJobTitle, style: AppType.h3),
                  Gap.vXs,
                  Text(
                    '${widget.workerName} · ${s.endJobBody}',
                    style: AppType.bodyMuted,
                  ),
                ],
              ),
            ),
            for (final r in _reasons)
              _ReasonRow(
                reason: r,
                selected: picked?.code == r.code,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _picked = r;
                    _error = null;
                  });
                },
              ),
            if (picked != null && picked.needsNote)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.x4l,
                  Gap.x3l,
                  Gap.x4l,
                  0,
                ),
                child: TextField(
                  controller: _note,
                  autofocus: true,
                  maxLength: 255,
                  minLines: 1,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: s.endJobNoteHint,
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            if (_error case final message?)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.x4l, Gap.lg, Gap.x4l, 0),
                child: Text(
                  message,
                  style: AppType.caption.copyWith(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.x4l,
                Gap.x3l,
                Gap.x4l,
                Gap.x4l,
              ),
              child: Column(
                children: [
                  KwButton(
                    label: s.endJobConfirm,
                    icon: Icons.stop_circle_outlined,
                    busy: _busy,
                    // Dark, not the app's yellow: irreversible and nobody should
                    // be nudged towards it.
                    variant: KwButtonVariant.dark,
                    onPressed: _busy ? null : _submit,
                  ),
                  Gap.vMd,
                  Pressable(
                    onTap: _busy ? null : () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      child: Text(
                        s.endJobCancel,
                        textAlign: TextAlign.center,
                        style: AppType.bodyStrong.copyWith(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final EndReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.x4l,
        vertical: Gap.x3l,
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? AppColors.black : AppColors.border,
          ),
          Gap.hXl,
          Expanded(
            child: Text(
              reason.label,
              style: selected ? AppType.bodyStrong : AppType.body,
            ),
          ),
        ],
      ),
    ),
  );
}
