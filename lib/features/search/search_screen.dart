import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/pressable.dart';
import '../../core/async/live_poll.dart';
import '../../core/async/loadable.dart';
import '../../core/responsive/responsive.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/session.dart';
import '../../widgets/kw_async.dart';
import '../../widgets/kw_common.dart';
import '../../widgets/kw_field.dart';
import '../../widgets/kw_scaffold.dart';
import '../labour_detail/labour_detail_screen.dart';
import '../location/location_picker_screen.dart';
import 'widgets/crew_booking_sheet.dart';
import 'widgets/crew_group_header.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/labour_card.dart';
import 'widgets/search_map.dart';

/// What one search came back with. An ordinary search is a flat list; a crew
/// search ("I need 4 painters") is the same workers in same-area [groups], and
/// [labours] is those workers flattened so the map still has every pin.
class _SearchResult {
  const _SearchResult({this.labours = const [], this.groups = const []});

  final List<Labour> labours;
  final List<LabourGroup> groups;

  bool get isGrouped => groups.isNotEmpty;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
  final _query = TextEditingController();
  final _sheetController = DraggableScrollableController();

  late final Loadable<_SearchResult> _results = Loadable(_fetch);
  late final Loadable<List<Skill>> _skills = Loadable(
    () => context.repo.skills(),
  );

  LabourFilters _filters = const LabourFilters();
  String _search = '';
  Timer? _debounce;
  int? _selectedId;

  late final Session _session = SessionScope.read(context);
  GeoPoint? _fetchedFrom;

  /// Bumped by every [_fetch], so a poll can tell that a search the Thekedar
  /// started (a new filter, a new name) went out while it was in flight.
  int _fetchSerial = 0;

  /// Labour switch their duty on and off from their own phone, and none of it
  /// reaches this map on its own. Runs only while this tab is on screen and
  /// the app is in the foreground.
  late final LivePoll _live = LivePoll(
    onTick: _pollLabours,
    interval: ApiConfig.labourMapPollInterval,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _results.load();
      _skills.load();
    });
  }

  GeoPoint get _origin {
    final user = _session.user;
    return GeoPoint(
      user?.latitude ?? ApiConfig.fallbackLat,
      user?.longitude ?? ApiConfig.fallbackLng,
    );
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final origin = _origin;
    final previous = _fetchedFrom;
    if (previous != null &&
        previous.lat == origin.lat &&
        previous.lng == origin.lng) {
      return;
    }
    _results.refetchWith(_fetch);
  }

  Future<void> _changeLocation() async {
    await LocationPickerScreen.push(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The home shell freezes tabs that are not showing with a disabled
    // TickerMode — a hidden map has nobody to show a new pin to.
    _live.sync(wanted: TickerMode.valuesOf(context).enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _live.resume();
      unawaited(_pollLabours());
    } else {
      _live.pause();
    }
  }

  /// Re-runs the current search in the background. Goes around [Loadable] on
  /// purpose: a dropped poll must not swap a list that is fine for an error,
  /// and a stale answer must not land on top of a search started meanwhile.
  Future<void> _pollLabours() async {
    if (!_results.hasValue || _results.isLoading) return;
    final serial = _fetchSerial;
    final result = await _fetch();
    if (!mounted || _fetchSerial != serial + 1 || _results.isLoading) return;
    _results.setValue(result);
  }

  Future<_SearchResult> _fetch() async {
    _fetchSerial++;
    final origin = _origin;
    _fetchedFrom = origin;

    // "I need 4 painters": the server bunches the workers by neighbourhood.
    // The name box, rate cap and sort do not apply here — they would pick
    // workers out of a group and leave it short of the size that was asked for.
    if (_filters.isCrew) {
      final groups = await context.repo.labourGroups(
        lat: origin.lat,
        lng: origin.lng,
        skillId: _filters.skillId!,
        count: _filters.crewSize,
        radiusKm: _filters.radiusKm,
      );
      return _SearchResult(
        labours: [for (final group in groups) ...group.workers],
        groups: groups,
      );
    }

    // Fetch all labours from the new API
    final allLabours = await context.repo.allLaboursForSearch();
    
    final query = _search.trim().toLowerCase();
    
    // Filter locally based on distance from origin and current radius
    final filtered = allLabours.where((labour) {
      // Filter by search query (name or city)
      if (query.isNotEmpty) {
        final matches = labour.name.toLowerCase().contains(query) ||
            (labour.city?.toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }

      if (labour.latitude == null || labour.longitude == null) return false;

      final labourPos = GeoPoint(labour.latitude!, labour.longitude!);
      final distance = origin.distanceKmTo(labourPos);

      return distance <= _filters.radiusKm;
    }).map((l) {
      final labourPos = GeoPoint(l.latitude!, l.longitude!);
      return l.copyWith(distanceKm: origin.distanceKmTo(labourPos));
    }).toList();

    return _SearchResult(labours: _filters.applyLocal(filtered));
  }

  void _onQueryChanged(String value) {
    _search = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _results.refetchWith(_fetch);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.dispose();
    _debounce?.cancel();
    _session.removeListener(_onSessionChanged);
    _query.dispose();
    _results.dispose();
    _skills.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _results.load(silent: true);

  void _openDetail(Labour labour) {
    setState(() => _selectedId = labour.id);
    if (context.usesTwoPane) return;
    Navigator.of(context).pushNamed(Routes.labourDetail, arguments: labour);
  }

  void _connect(Labour labour) {
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
      // We handle the safe area and status bar padding internally.
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: ListenableBuilder(
              listenable: _results,
              builder: (context, _) {
                final result = _results.value ?? const _SearchResult();
                final rows = result.labours;

                return Stack(
                  children: [
                    // Background Map
                    Positioned.fill(
                      child: SearchMap(
                        key: ValueKey('map-${_origin.lat}-${_origin.lng}-${rows.length}-${_filters.radiusKm}'),
                        origin: _origin,
                        radiusKm: _filters.radiusKm,
                        labours: rows,
                        selectedId: _selectedId,
                        onPinTap: _openDetail,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 140,
                          bottom: MediaQuery.of(context).size.height * 0.4,
                        ),
                      ),
                    ),

                    // Floating Search & Filter Bar (just below the restored header)
                    Positioned(
                      top: Gap.lg,
                      left: Gap.lg,
                      right: Gap.lg,
                      child: _floatingSearchBox(),
                    ),

                    // Draggable Labour List
                    _draggableList(result),

                    // Floating Location/Re-center button
                    Positioned(
                      bottom: (MediaQuery.of(context).size.height * 0.4) + 20,
                      right: Gap.lg,
                      child: Pressable(
                        onTap: () {
                          _sheetController.animateTo(
                            0.15,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.floatingShadow,
                          ),
                          child: const Icon(Icons.my_location_rounded, size: 20),
                        ),
                      ),
                    ),

                    // Wide screen detail pane
                    if (context.usesTwoPane && _selectedId != null)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width - Breakpoints.listPaneWidth,
                        child: Material(
                          elevation: 16,
                          color: AppColors.canvas,
                          child: _detailPane(rows),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final s = context.s;
    final user = context.session.user;
    final location = user?.address ?? user?.city ?? s.setLocation;

    return KwHeader(
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.yourLocation,
                    style: AppType.micro.copyWith(
                      color: AppColors.black.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          Pressable(
            onTap: _changeLocation,
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.black),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    location,
                    style: AppType.bodyStrong.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
                ],
              ),
            ),
            Gap.hXl,
            _notificationBell(),
          ],
        ),
      ),
    );
  }

  Widget _notificationBell() {
    return Pressable(
      onTap: () => _toast(context.s.noNotifications),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.veil10,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.notifications_none_rounded, size: 19, color: AppColors.black),
      ),
    );
  }

  Widget _floatingSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: KwSearchBar(
        controller: _query,
        hintText: context.s.searchHint,
        onChanged: _onQueryChanged,
        trailing: _filterButton(),
      ),
    );
  }

  Widget _filterButton() {
    final count = _filters.activeCount;
    return Pressable(
      onTap: _openFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.yellow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, size: 16),
            if (count > 0) ...[
              Gap.hXs,
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.black, shape: BoxShape.circle),
                child: Text('$count', style: AppType.nano.copyWith(color: AppColors.yellow, fontSize: 8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _draggableList(_SearchResult result) {
    final rows = result.labours;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.4,
      minChildSize: 0.15,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.15, 0.4, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.only(
                  left: Gap.xl,
                  right: Gap.xl,
                  bottom: Gap.md,
                ),
                child: _listHeader(result),
              ),

              // Crew search: what is being asked for, and how to change it.
              _crewBanner(),

              // List
              Expanded(
                child: _results.isInitialLoad
                    ? _skeletonList()
                    : rows.isEmpty
                    ? _emptyState()
                    : _results.error != null
                    ? _errorState()
                    : result.isGrouped
                    ? _groupedList(result.groups, scrollController)
                    : _actualList(rows, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _listHeader(_SearchResult result) {
    final s = context.s;
    final count = result.labours.length;
    return Row(
      children: [
        Expanded(
          child: Text(
            _results.isInitialLoad
                ? s.searching
                : count == 0
                ? s.noneFound
                : result.isGrouped
                ? s.crewAreasFound(result.groups.length, count)
                : s.labourFound(count),
            style: AppType.bodyStrong,
          ),
        ),
        // A group is already ordered nearest-area-first; re-sorting it by rate
        // or rating would scramble the very thing that makes it a group.
        if (!result.isGrouped)
          Pressable(
            onTap: _openSort,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 14),
                  Gap.hSm,
                  Text(
                    _filters.sort.labelIn(s),
                    style: AppType.buttonSmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actualList(List<Labour> rows, ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, MediaQuery.of(context).padding.bottom + Gap.xl),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final labour = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: LabourCard(
            labour: labour,
            selected: labour.id == _selectedId,
            onTap: () => _openDetail(labour),
            onConnect: () => _connect(labour),
          ),
        );
      },
    );
  }

  String? get _crewSkillName => _skills.value
      ?.where((skill) => skill.id == _filters.skillId)
      .firstOrNull
      ?.name;

  /// "4 Painter needed ✕" while a crew search is on — and, when a count has
  /// been picked with no work type to go with it, the nudge to pick one (a
  /// crew of nothing in particular has no groups to show).
  Widget _crewBanner() {
    if (_filters.crewSize <= 1) return const SizedBox.shrink();

    final s = context.s;
    final needsSkill = _filters.skillId == null;
    final label = needsSkill
        ? s.crewPickSkill
        : s.crewActiveChip(_filters.crewSize, _crewSkillName ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.md),
      child: Pressable(
        onTap: needsSkill
            ? _openFilters
            : () {
                setState(() => _filters = _filters.copyWith(crewSize: 1));
                _results.refetchWith(_fetch);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.xl,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            color: needsSkill ? AppColors.canvas : AppColors.yellowLight,
            borderRadius: Radii.rPill,
            border: Border.all(
              color: needsSkill ? AppColors.border : AppColors.yellow,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, size: 16),
              Gap.hMd,
              Expanded(
                child: Text(
                  label,
                  style: AppType.buttonSmall.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!needsSkill) const Icon(Icons.close_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Same-area groups, each headed by its area and booked as one, with a
  /// horizontal line before the next area starts.
  Widget _groupedList(
    List<LabourGroup> groups,
    ScrollController scrollController,
  ) {
    final s = context.s;

    final items = <Widget>[
      for (final (i, group) in groups.indexed) ...[
        if (i > 0) AreaDivider(label: s.crewNextArea),
        CrewGroupHeader(group: group, onBook: () => _bookGroup(group)),
        for (final labour in group.workers)
          LabourCard(
            labour: labour,
            selected: labour.id == _selectedId,
            onTap: () => _openDetail(labour),
            onConnect: () => _connect(labour),
          ),
      ],
    ];

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.of(context).padding.bottom + Gap.xl,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => items[i],
    );
  }

  Future<void> _bookGroup(LabourGroup group) async {
    final skillId = _filters.skillId;
    if (skillId == null) return;

    final crew = await CrewBookingSheet.show(
      context,
      group: group,
      skillId: skillId,
      skillName: _crewSkillName ?? '',
      size: _filters.crewSize,
      origin: _origin,
      radiusKm: _filters.radiusKm,
    );
    if (crew == null || !mounted) return;

    await Navigator.of(context).pushNamed(Routes.crewStatus, arguments: crew);
  }

  Widget _skeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      itemCount: 3,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: Gap.md),
        child: LabourCardSkeleton(),
      ),
    );
  }

  Widget _emptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.x3l),
        child: KwEmptyState(
          icon: Icons.person_search_rounded,
          title: context.s.noLabourTitle,
          message: context.s.noLabourMessage,
          action: _filters.isDefault
              ? null
              : TextButton(
                  onPressed: () {
                    setState(() => _filters = LabourFilters(sort: _filters.sort));
                    _results.refetchWith(_fetch);
                  },
                  child: Text(context.s.clearFilters),
                ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return ApiErrorState(
      error: _results.error!,
      onRetry: () => _results.load(),
    );
  }

  Widget _detailPane(List<Labour> rows) {
    final selected = rows.where((l) => l.id == _selectedId).firstOrNull;
    if (selected == null) return const SizedBox.shrink();
    return LabourDetailScreen(
      key: ValueKey('pane-${selected.id}'),
      labourId: selected.id,
      preview: selected,
      embedded: true,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
