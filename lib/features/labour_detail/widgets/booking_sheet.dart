import 'package:flutter/material.dart';

import '../../../core/animations/entrance.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_async.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';
import '../../../widgets/kw_field.dart';

/// Booking confirmation sheet: pick a day, full/half, and see the price update
/// live before committing.
class BookingSheet extends StatefulWidget {
  const BookingSheet({super.key, required this.labour});

  final Labour labour;

  /// Resolves to the created booking, so the caller can take the user straight
  /// to tracking rather than only knowing that *something* succeeded.
  static Future<Booking?> show(
    BuildContext context, {
    required Labour labour,
  }) => showModalBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    builder: (_) => BookingSheet(labour: labour),
  );

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  late final TextEditingController _address = TextEditingController();
  final _notes = TextEditingController();

  int _dayOffset = 0;
  DayType _dayType = DayType.full;
  bool _submitting = false;
  String? _addressError;

  int get _price => _dayType == DayType.full
      ? widget.labour.dailyRate
      : (widget.labour.dailyRate / 2).round();

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in user's saved address; `address` is required
    // by POST /v1/thekedar/bookings. `read` because subscribing from initState
    // throws — and a one-shot prefill has nothing to subscribe for.
    final user = SessionScope.read(context).user;
    _address.text = user?.address ?? user?.city ?? '';
  }

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  DateTime get _selectedDate => DateTime.now().add(Duration(days: _dayOffset));

  Future<void> _submit() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _addressError = context.s.addressRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _addressError = null;
    });

    final user = context.session.user;

    try {
      final booking = await context.repo.createBooking(
        labourId: widget.labour.id,
        skillId: widget.labour.skills.firstOrNull?.id,
        workDate: _selectedDate,
        // The API validates `H:i`; full days start at 9, half days at 14.
        startTime: _dayType == DayType.full ? '09:00' : '14:00',
        dayType: _dayType,
        offeredAmount: _price,
        address: _address.text.trim(),
        city: user?.city,
        latitude: user?.latitude,
        longitude: user?.longitude,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(booking);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        // Keyboard-aware: the address field sits near the bottom of the sheet.
        padding: EdgeInsets.fromLTRB(
          Gap.x4l,
          0,
          Gap.x4l,
          Gap.x4l + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: Stagger.wrap(
            step: const Duration(milliseconds: 45),
            offset: 14,
            children: [
              Row(
                children: [
                  KwAvatar(initials: widget.labour.initials, size: 42),
                  Gap.hXl,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.labour.name,
                          style: AppType.h4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.labour.primarySkillIn(s),
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Gap.v24,
              KwSectionTitle(s.whichDay),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, _) => Gap.hMd,
                  itemBuilder: (context, i) {
                    final date = DateTime.now().add(Duration(days: i));
                    return _DayChip(
                      weekday: i == 0
                          ? s.today
                          : i == 1
                          ? s.tomorrow
                          : s.weekdaysShort[date.weekday - 1],
                      day: '${date.day}',
                      month: s.monthsShort[date.month - 1],
                      selected: i == _dayOffset,
                      onTap: () => setState(() => _dayOffset = i),
                    );
                  },
                ),
              ),
              Gap.v20,
              KwSectionTitle(s.howMuchWork),
              Row(
                children: [
                  Expanded(
                    child: _TypeChip(
                      label: s.fullDay,
                      sub: s.eightHours,
                      selected: _dayType == DayType.full,
                      onTap: () => setState(() => _dayType = DayType.full),
                    ),
                  ),
                  Gap.hLg,
                  Expanded(
                    child: _TypeChip(
                      label: s.halfDay,
                      sub: s.fourHours,
                      selected: _dayType == DayType.half,
                      onTap: () => setState(() => _dayType = DayType.half),
                    ),
                  ),
                ],
              ),
              Gap.v20,
              KwSectionTitle(s.whereIsWork),
              KwTextField(
                controller: _address,
                hintText: s.addressHint,
                errorText: _addressError,
                onChanged: (_) {
                  if (_addressError != null) {
                    setState(() => _addressError = null);
                  }
                },
              ),
              Gap.vLg,
              KwTextField(
                controller: _notes,
                hintText: s.bookingNotesHint,
              ),
              Gap.v24,
              Container(
                padding: const EdgeInsets.all(Gap.xxl),
                decoration: BoxDecoration(
                  color: AppColors.yellowLight,
                  borderRadius: Radii.rSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.total, style: AppType.label),
                          Text(
                            '${_selectedDate.day} '
                            '${s.monthsShort[_selectedDate.month - 1]} · '
                            '${_dayType.labelIn(s)}',
                            style: AppType.caption.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Price slides when the day type changes.
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Text(
                        '₹$_price',
                        key: ValueKey(_price),
                        style: AppType.h2,
                      ),
                    ),
                  ],
                ),
              ),
              Gap.v20,
              KwButton(
                label: s.confirmBooking,
                icon: Icons.event_available_rounded,
                size: KwButtonSize.large,
                busy: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.day,
    required this.month,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final String day;
  final String month;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.92,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.white,
          borderRadius: Radii.rSm,
          border: Border.all(
            color: selected ? AppColors.black : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weekday,
              style: AppType.nano.copyWith(
                fontSize: 10,
                color: selected ? AppColors.yellow : AppColors.muted,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              day,
              style: AppType.bodyStrong.copyWith(
                fontSize: 17,
                color: selected ? AppColors.white : AppColors.black,
              ),
            ),
            Text(
              month,
              style: AppType.nano.copyWith(
                fontSize: 9,
                color: selected
                    ? AppColors.white.withValues(alpha: 0.7)
                    : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enter,
        padding: const EdgeInsets.symmetric(vertical: Gap.xl),
        decoration: BoxDecoration(
          color: selected ? AppColors.yellow : AppColors.white,
          borderRadius: Radii.rSm,
          border: Border.all(
            color: selected ? AppColors.yellow : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppType.bodyStrong.copyWith(fontSize: 14)),
            Text(sub, style: AppType.micro),
          ],
        ),
      ),
    );
  }
}
