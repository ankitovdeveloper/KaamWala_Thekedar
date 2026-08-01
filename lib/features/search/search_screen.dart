import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/entrance.dart';
import '../../core/animations/pressable.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_field.dart';
import '../../widgets/kw_scaffold.dart';
import '../labour_detail/labour_detail_screen.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/labour_card.dart';
import 'widgets/map_canvas.dart';

/// Map + list backed by `GET /v1/thekedar/labour`.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _scroll = ScrollController();
  final _query = TextEditingController();

  late final Loadable<List<Labour>> _results = Loadable(_fetch);
  late final Loadable<List<Skill>> _skills = Loadable(
    () => context.repo.skills(),
  );

  LabourFilters _filters = const LabourFilters();
  String _search = '';
  Timer? _debounce;
  int? _selectedId;

  /// 0 → map fully open, 1 → map collapsed. Driven by list scroll offset.
  double _collapse = 0;

  static const _mapMax = 200.0;
  static const _mapMin = 96.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _results.load();
      // The filter sheet needs the master list, but the screen doesn't wait
      // on it — a failed skills call must not block search results.
      _skills.load();
    });
  }

  /// Search origin. Falls back to the configured city centre until a location
  /// plugin is wired in; the user's saved coordinates win when present.
  (double lat, double lng) get _origin {
    final user = context.session.user;
    return (
      user?.latitude ?? ApiConfig.fallbackLat,
      user?.longitude ?? ApiConfig.fallbackLng,
    );
  }

  Future<List<Labour>> _fetch() async {
    final (lat, lng) = _origin;
    final rows = await context.repo.searchLabours(
      lat: lat,
      lng: lng,
      skillId: _filters.skillId,
      query: _search,
      radiusKm: _filters.radiusKm,
      sort: _filters.sort,
    );
    // Rate cap and the availability toggle have no query parameter.
    return _filters.applyLocal(rows);
  }

  void _onScroll() {
    final next = (_scroll.offset / 130).clamp(0.0, 1.0);
    if ((next - _collapse).abs() > 0.005) {
      setState(() => _collapse = next);
    }
  }

  /// Typing shouldn't fire a request per keystroke.
  void _onQueryChanged(String value) {
    _search = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _results.refetchWith(_fetch);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _query.dispose();
    _results.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _results.load(silent: true);

  void _openDetail(Labour labour) {
    setState(() => _selectedId = labour.id);
    if (context.usesTwoPane) return; // Detail renders in the side pane.
    Navigator.of(context).pushNamed(Routes.labourDetail, arguments: labour);
  }

  void _connect(Labour labour) {
    // "Connect" opens the profile, where Book Now creates the booking.
    _openDetail(labour);
  }

  Future<void> _openFilters() async {
    final result = await FilterSheet.show(
      context,
      initial: _filters,
      skills: _skills.value ?? const [],
    );
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    _results.refetchWith(_fetch);
  }

  Future<void> _openSort() async {
    final result = await SortSheet.show(context, _filters.sort);
    if (result == null || !mounted) return;
    setState(() => _filters = _filters.copyWith(sort: result));
    _results.refetchWith(_fetch);
  }

  @override
  Widget build(BuildContext context) {
    return KwScaffold(
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: ListenableBuilder(
              listenable: _results,
              builder: (context, _) {
                final rows = _results.value ?? const <Labour>[];
                if (!context.usesTwoPane) {
                  return _mapAndList(rows, collapsible: true);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: Breakpoints.listPaneWidth,
                      child: _mapAndList(rows, collapsible: false),
                    ),
                    const VerticalDivider(
                      width: 0.5,
                      thickness: 0.5,
                      color: AppColors.border,
                    ),
                    Expanded(child: _detailPane(rows)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _topBar() {
    final user = context.session.user;
    final location = user?.address ?? user?.city ?? 'Location set karein';

    return KwHeader(
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: FadeSlideIn(
                from: SlideFrom.left,
                offset: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Aapka location',
                      style: AppType.micro.copyWith(
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    Pressable(
                      scale: 0.97,
                      onTap: () => _toast('Location badalna jald aayega'),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppColors.black,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              location,
                              style: AppType.bodyStrong.copyWith(fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.black,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Gap.hXl,
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              from: SlideFrom.right,
              offset: 14,
              child: _notificationBell(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationBell() {
    return Pressable(
      scale: 0.88,
      onTap: () => _toast('Abhi koi naya notification nahi'),
      semanticLabel: 'Notifications',
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.veil10,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_none_rounded,
          size: 19,
          color: AppColors.black,
        ),
      ),
    );
  }

  // ── Map + list ────────────────────────────────────────────────────────────

  Widget _mapAndList(List<Labour> rows, {required bool collapsible}) {
    final mapHeight = collapsible
        ? _mapMax - (_mapMax - _mapMin) * _collapse
        : 170.0;

    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
              height: mapHeight,
              child: MapCanvas(
                labours: rows,
                selectedId: _selectedId,
                height: mapHeight,
                onPinTap: _openDetail,
              ),
            ),
            Positioned(
              top: Gap.xl,
              left: Gap.xxl,
              right: Gap.xxl,
              // Search bar fades as the map collapses under it.
              child: IgnorePointer(
                ignoring: _collapse > 0.85,
                child: Opacity(
                  opacity: (1 - _collapse * 1.15).clamp(0.0, 1.0),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 160),
                    from: SlideFrom.top,
                    child: KwSearchBar(
                      controller: _query,
                      hintText: 'Electrician, Plumber dhundein...',
                      onChanged: _onQueryChanged,
                      trailing: _filterButton(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(child: _list(rows)),
      ],
    );
  }

  Widget _filterButton() {
    final count = _filters.activeCount;
    return Pressable(
      scale: 0.92,
      onTap: _openFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, size: 13, color: AppColors.black),
            Gap.hXs,
            Text('Filter', style: AppType.buttonSmall.copyWith(fontSize: 12)),
            AnimatedSize(
              duration: Motion.fast,
              curve: Motion.enter,
              child: count == 0
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: AppType.nano.copyWith(
                            fontSize: 9,
                            color: AppColors.yellow,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Labour> rows) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.black,
      backgroundColor: AppColors.yellow,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverContentWidth(
            sliver: SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                Gap.x3l,
                context.pagePadding,
                Gap.md,
              ),
              sliver: SliverToBoxAdapter(child: _listHeader(rows.length)),
            ),
          ),
          if (_results.isInitialLoad)
            SliverContentWidth(
              sliver: SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                sliver: SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (_, _) => const LabourCardSkeleton(),
                ),
              ),
            )
          else if (_results.error != null && rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ApiErrorState(
                error: _results.error!,
                onRetry: () => _results.load(),
              ),
            )
          else if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: KwEmptyState(
                icon: Icons.person_search_rounded,
                title: 'Koi kaam wala nahi mila',
                message: 'Filter thoda kam karein ya doosra skill try karein.',
                action: _filters.isDefault
                    ? null
                    : TextButton(
                        onPressed: () {
                          setState(
                            () => _filters = LabourFilters(sort: _filters.sort),
                          );
                          _results.refetchWith(_fetch);
                        },
                        child: Text(
                          'Filter hatao',
                          style: AppType.buttonSmall.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
              ),
            )
          else
            SliverContentWidth(
              sliver: SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final labour = rows[i];
                    return FadeSlideIn.staggered(
                      // Keying on id replays the entrance when the result set
                      // changes, but not when a card merely moves.
                      key: ValueKey('card-${labour.id}'),
                      index: i,
                      beginScale: 0.97,
                      child: LabourCard(
                        labour: labour,
                        selected: labour.id == _selectedId,
                        onTap: () => _openDetail(labour),
                        onConnect: () => _connect(labour),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: Gap.x4l)),
        ],
      ),
    );
  }

  Widget _listHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: Text(
              key: ValueKey('$count-${_results.isLoading}'),
              _results.isInitialLoad
                  ? 'Dhoond rahe hain...'
                  : count == 0
                  ? 'Koi nahi mila'
                  : '$count kaam wale milein paas mein',
              style: AppType.caption.copyWith(fontSize: 13),
            ),
          ),
        ),
        Pressable(
          scale: 0.94,
          onTap: _openSort,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: Radii.rPill,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _filters.sort.label,
                  style: AppType.micro.copyWith(
                    fontSize: 12,
                    color: AppColors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Gap.hXs,
                const Icon(
                  Icons.swap_vert_rounded,
                  size: 14,
                  color: AppColors.black,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Wide-window right pane: shows the selected worker, or a prompt.
  Widget _detailPane(List<Labour> rows) {
    final selected = rows.where((l) => l.id == _selectedId).firstOrNull;

    return AnimatedSwitcher(
      duration: Motion.normal,
      switchInCurve: Motion.enter,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: selected == null
          ? const KwEmptyState(
              key: ValueKey('empty-pane'),
              icon: Icons.touch_app_rounded,
              title: 'Kisi kaam wale ko chunein',
              message: 'List ya map se select karein, detail yahan khulegi.',
            )
          : LabourDetailScreen(
              key: ValueKey('pane-${selected.id}'),
              labourId: selected.id,
              preview: selected,
              embedded: true,
            ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
