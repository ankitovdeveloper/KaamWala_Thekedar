import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/async/live_poll.dart';
import '../../core/async/loadable.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_button.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_scaffold.dart';

/// A crew booking as it fills up — `GET /v1/thekedar/crews/{id}`.
///
/// "2 of 5 confirmed": who has said yes, who is still being waited on, and the
/// reassurance that a worker who says no does not leave the Thekedar starting
/// over — the server asks the next nearest on its own.
///
/// Polled while it is open. That is not only to redraw: reading the crew is
/// also what makes the server pass a request nobody answered on to somebody
/// else, so a Thekedar watching this screen is what keeps the crew moving.
class CrewStatusScreen extends StatefulWidget {
  const CrewStatusScreen({super.key, required this.crewId, this.preview});

  final int crewId;

  /// What the booking sheet just got back, painted at once while the first
  /// poll is on its way.
  final Crew? preview;

  @override
  State<CrewStatusScreen> createState() => _CrewStatusScreenState();
}

class _CrewStatusScreenState extends State<CrewStatusScreen>
    with WidgetsBindingObserver {
  late final Loadable<Crew> _crew = Loadable(
    () => context.repo.crew(widget.crewId),
  );

  late final LivePoll _live = LivePoll(
    onTick: () => _crew.load(silent: true),
    interval: ApiConfig.stagePollInterval,
  );

  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _crew.addListener(_syncLive);

    final preview = widget.preview;
    if (preview != null) _crew.setValue(preview);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _crew.load(silent: preview != null);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.dispose();
    _crew.removeListener(_syncLive);
    _crew.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _live.resume();
      _crew.load(silent: true);
    } else {
      _live.pause();
    }
  }

  /// A filled crew is still worth watching — a worker can pull out and reopen
  /// a place — so only a cancelled one stops the timer.
  void _syncLive() => _live.sync(wanted: !(_crew.value?.isCancelled ?? false));

  Future<void> _cancel() async {
    final s = context.s;

    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.crewCancelConfirmTitle, style: AppType.h4),
        content: Text(s.crewCancelConfirmBody, style: AppType.bodyMuted),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              s.keepIt,
              style: AppType.buttonSmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              s.crewCancelAction,
              style: AppType.buttonSmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final cancelled = await context.repo.cancelCrew(widget.crewId);
      if (!mounted) return;
      _crew.setValue(cancelled);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(context, e))));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: Column(
        children: [
          _header(),
          Expanded(
            child: AsyncView<Crew>(
              state: _crew,
              builder: (context, crew) => _body(crew),
              onRetry: () => _crew.load(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final s = context.s;

    return ListenableBuilder(
      listenable: _crew,
      builder: (context, _) {
        final crew = _crew.value;
        final subtitle = [
          if (crew?.skillName != null) crew!.skillName!,
          if (crew?.workDate != null)
            '${crew!.workDate!.day} ${s.monthsShort[crew.workDate!.month - 1]}',
        ].join(' · ');

        return KwHeader(
          padding: const EdgeInsets.fromLTRB(8, 8, 18, 14),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                KwIconButton(
                  icon: Icons.arrow_back_rounded,
                  iconSize: 20,
                  tooltip: s.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Gap.hXl,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.crewStatusTitle,
                        style: AppType.h3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: AppType.micro.copyWith(
                            color: AppColors.black.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(Crew crew) {
    final s = context.s;

    return RefreshIndicator(
      onRefresh: () => _crew.load(silent: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Gap.x3l,
          Gap.x3l,
          Gap.x3l,
          MediaQuery.paddingOf(context).bottom + Gap.x5l,
        ),
        children: [
          if (crew.isCancelled) _cancelledBanner(crew) else _statusCard(crew),
          if (crew.replaced > 0 && !crew.isCancelled) ...[
            Gap.vXl,
            _note(Icons.autorenew_rounded, s.crewReplacedNote(crew.replaced)),
          ],
          if (!crew.isCancelled) ...[
            Gap.vXl,
            Container(
              padding: const EdgeInsets.all(Gap.xxl),
              decoration: BoxDecoration(
                color: AppColors.black,
                borderRadius: Radii.rMd,
              ),
              child: Text(
                s.crewReplaceNote,
                style: AppType.caption.copyWith(
                  color: AppColors.white.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ),
            Gap.v20,
            KwButton(
              label: s.crewDone,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Gap.vLg,
            KwButton(
              label: s.crewCancelAction,
              variant: KwButtonVariant.danger,
              busy: _cancelling,
              onPressed: _cancel,
            ),
          ] else ...[
            Gap.v20,
            KwButton(
              label: s.back,
              variant: KwButtonVariant.outline,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusCard(Crew crew) {
    final s = context.s;

    final confirmedPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: crew.isFilled ? AppColors.successBg : AppColors.yellowLight,
        borderRadius: Radii.rPill,
      ),
      child: Text(
        crew.isFilled
            ? s.crewFilled
            : s.crewConfirmedOf(crew.confirmed, crew.size),
        style: AppType.micro.copyWith(
          fontWeight: FontWeight.w700,
          color: crew.isFilled ? AppColors.successDark : AppColors.pendingText,
        ),
      ),
    );

    return KwCard(
      padding: const EdgeInsets.all(Gap.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.crewStatusTitle, style: AppType.bodyStrong),
              ),
              confirmedPill,
            ],
          ),
          Gap.vLg,
          ClipRRect(
            borderRadius: Radii.rPill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: crew.progress),
              duration: Motion.normal,
              curve: Motion.enter,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation(AppColors.yellowDark),
              ),
            ),
          ),
          Gap.vXl,
          for (final member in crew.members)
            _MemberRow(
              key: ValueKey('member-${member.bookingId}'),
              member: member,
              skillName: crew.skillName,
              onTap: member.isConfirmed
                  ? () => Navigator.of(context).pushNamed(
                      Routes.bookingDetail,
                      arguments: member.bookingId,
                    )
                  : null,
            ),
          if (crew.pending > 0 || crew.openSlots > 0) _searchingRow(crew),
        ],
      ),
    );
  }

  /// "Searching… 3 more workers being notified" — or, when there is nobody left
  /// to notify, the honest version of it.
  Widget _searchingRow(Crew crew) {
    final s = context.s;
    final stalled = crew.pending == 0 && crew.openSlots > 0;

    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ),
          Gap.hXl,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.crewSearching,
                  style: AppType.bodyStrong.copyWith(color: AppColors.muted),
                ),
                Text(
                  stalled
                      ? s.crewNoMoreNearby
                      : s.crewMoreNotified(crew.pending + crew.openSlots),
                  style: AppType.micro,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelledBanner(Crew crew) {
    final s = context.s;

    return KwEmptyState(
      icon: Icons.group_off_rounded,
      title: s.crewCancelledTitle,
      message: crew.address,
    );
  }

  Widget _note(IconData icon, String text) => Container(
    padding: const EdgeInsets.all(Gap.xxl),
    decoration: BoxDecoration(
      color: AppColors.yellowLight,
      borderRadius: Radii.rMd,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.pendingText),
        Gap.hLg,
        Expanded(child: Text(text, style: AppType.caption)),
      ],
    ),
  );
}

/// One worker in the crew: who, how good, how far, and whether they have said
/// yes yet.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.skillName,
    this.onTap,
  });

  final CrewMember member;
  final String? skillName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final confirmed = member.isConfirmed;

    final detail = [
      ?skillName,
      if (member.rating > 0) '${member.rating.toStringAsFixed(1)}★',
      ?member.distanceLabelIn(s),
    ].join(' · ');

    return FadeSlideIn(
      offset: 8,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.rSm,
          child: Row(
            children: [
              KwAvatar(
                initials: member.labour.initials,
                photoUrl: member.labour.photoUrl,
                size: 38,
              ),
              Gap.hXl,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member.labour.name,
                      style: AppType.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: AppType.micro,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Gap.hMd,
              KwStatusBadge(
                label: confirmed ? s.crewAccepted : s.crewWaiting,
                tone: confirmed ? KwStatusTone.confirmed : KwStatusTone.pending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
