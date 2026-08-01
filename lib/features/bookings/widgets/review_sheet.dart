import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/animations/entrance.dart';
import '../../../core/animations/pressable.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/models.dart';
import '../../../data/session.dart';
import '../../../widgets/kw_button.dart';
import '../../../widgets/kw_common.dart';
import '../../../widgets/kw_field.dart';

/// What the sheet returns; feeds `POST /v1/thekedar/bookings/{id}/review`.
class ReviewDraft {
  const ReviewDraft({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

/// Star picker plus an optional comment. The API requires `rating` 1–5 and
/// caps `comment` at 500 characters.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.booking});

  final Booking booking;

  static Future<ReviewDraft?> show(
    BuildContext context, {
    required Booking booking,
  }) => showModalBottomSheet<ReviewDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    builder: (_) => ReviewSheet(booking: booking),
  );

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
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
          children: Stagger.wrap(
            step: const Duration(milliseconds: 45),
            children: [
              Row(
                children: [
                  KwAvatar(initials: widget.booking.labour.initials, size: 42),
                  Gap.hXl,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.booking.labour.name,
                          style: AppType.h4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.booking.skillName ?? s.workGeneric,
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Gap.v24,
              Text(
                s.howWasWork,
                style: AppType.h3,
                textAlign: TextAlign.center,
              ),
              Gap.v20,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Pressable(
                      scale: 0.85,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedScale(
                          duration: Motion.normal,
                          curve: Motion.spring,
                          scale: i <= _rating ? 1.0 : 0.85,
                          child: Icon(
                            i <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 40,
                            color: i <= _rating
                                ? AppColors.yellow
                                : AppColors.border,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Gap.vXl,
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Text(
                  s.ratingLabels[_rating - 1],
                  key: ValueKey(_rating),
                  textAlign: TextAlign.center,
                  style: AppType.bodyStrong.copyWith(color: AppColors.muted),
                ),
              ),
              Gap.v24,
              KwTextField(
                controller: _comment,
                hintText: s.reviewCommentHint,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
              ),
              Gap.v24,
              KwButton(
                label: s.sendReview,
                icon: Icons.send_rounded,
                onPressed: () => Navigator.of(context).pop(
                  ReviewDraft(
                    rating: _rating,
                    comment: _comment.text.trim().isEmpty
                        ? null
                        : _comment.text.trim(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
