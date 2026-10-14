import 'package:flutter/material.dart';

import '../../../core/animations/entrance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_async.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';
import '../../../widgets/kw_field.dart';
import '../../labour_detail/widgets/booking_sheet.dart' show DayChip, TypeChip;

/// Books a whole group in one go: pick the day, full or half, where the work is,
/// and the server asks every worker in the group — and keeps asking until
/// [size] of them have said yes.
class CrewBookingSheet extends StatefulWidget {
  const CrewBookingSheet({
    super.key,
    required this.group,
    required this.skillId,
    required this.skillName,
    required this.size,
    required this.origin,
    required this.radiusKm,
  });

  final LabourGroup group;
  final int skillId;
  final String skillName;

  /// How many workers the Thekedar asked for — the group can be short of it.
  final int size;

  /// The point the groups were searched around. Sent as the job site so the
  /// server looks for the same workers the list showed.
  final GeoPoint origin;
  final int radiusKm;

  /// Resolves to the opened crew, so the caller can go straight to its status.
  static Future<Crew?> show(
    BuildContext context, {
    required LabourGroup group,
    required int skillId,
    required String skillName,
    required int size,
    required GeoPoint origin,
    required int radiusKm,
  }) => showModalBottomSheet<Crew>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    builder: (_) => CrewBookingSheet(
      group: group,
      skillId: skillId,
      skillName: skillName,
      size: size,
      origin: origin,
      radiusKm: radiusKm,
    ),
  );

  @override
  State<CrewBookingSheet> createState() => _CrewBookingSheetState();
}

class _CrewBookingSheetState extends State<CrewBookingSheet> {
  late final TextEditingController _address = TextEditingController();
  final _notes = TextEditingController();

  int _dayOffset = 0;
  DayType _dayType = DayType.full;
  bool _submitting = false;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    // `read`, not `of`: subscribing from initState throws, and a one-shot
    // prefill has nothing to subscribe for.
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

  /// Each worker at their own rate, scaled up when the group is short of the
  /// size asked for — the missing places are filled at about the same rate.
  int get _estimate {
    final group = widget.group;
    if (group.workers.isEmpty) return 0;

    final perWorker = group.dailyTotal / group.size;
    final day = _dayType == DayType.full ? perWorker : perWorker / 2;
    return (day * widget.size).round();
  }

  Future<void> _submit() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _addressError = context.s.addressRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _addressError = null;
    });

    try {
      final crew = await context.repo.createCrew(
        skillId: widget.skillId,
        size: widget.size,
        labourIds: widget.group.workerIds,
        workDate: _selectedDate,
        // The API validates `H:i`; full days start at 9, half days at 14.
        startTime: _dayType == DayType.full ? '09:00' : '14:00',
        dayType: _dayType,
        address: _address.text.trim(),
        city: context.session.user?.city,
        latitude: widget.origin.lat,
        longitude: widget.origin.lng,
        notes: _notes.text.trim(),
        radiusKm: widget.radiusKm,
      );
      if (!mounted) return;
      Navigator.of(context).pop(crew);
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
    final group = widget.group;

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
              Text(
                s.crewBookTitle(widget.size, widget.skillName),
                style: AppType.h3,
              ),
              Gap.vMd,
              Row(
                children: [
                  for (final w in group.workers.take(5))
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.md),
                      child: KwAvatar(
                        initials: w.initials,
                        photoUrl: w.photoUrl,
                        size: 34,
                      ),
                    ),
                  if (group.workers.length > 5)
                    Text(
                      '+${group.workers.length - 5}',
                      style: AppType.caption,
                    ),
                ],
              ),
              Gap.vMd,
              Text(s.crewHelper(widget.size), style: AppType.caption),
              Gap.v20,
              KwSectionTitle(s.whichDay),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, _) => Gap.hMd,
                  itemBuilder: (context, i) {
                    final date = DateTime.now().add(Duration(days: i));
                    return DayChip(
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
                    child: TypeChip(
                      label: s.fullDay,
                      sub: s.eightHours,
                      selected: _dayType == DayType.full,
                      onTap: () => setState(() => _dayType = DayType.full),
                    ),
                  ),
                  Gap.hLg,
                  Expanded(
                    child: TypeChip(
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
              KwTextField(controller: _notes, hintText: s.bookingNotesHint),
              Gap.v24,
              Container(
                padding: const EdgeInsets.all(Gap.xxl),
                decoration: BoxDecoration(
                  color: AppColors.yellowLight,
                  borderRadius: Radii.rSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.crewTotalEstimate(widget.size),
                                style: AppType.label,
                              ),
                              Text(
                                '${_selectedDate.day} '
                                '${s.monthsShort[_selectedDate.month - 1]} · '
                                '${_dayType.labelIn(s)}',
                                style: AppType.caption.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text('₹$_estimate', style: AppType.h2),
                      ],
                    ),
                    Gap.vMd,
                    Text(
                      s.crewEachOwnRate,
                      style: AppType.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Gap.v20,
              KwButton(
                label: s.crewConfirm,
                icon: Icons.groups_rounded,
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
