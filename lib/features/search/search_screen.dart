import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/animations/pressable.dart';
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
import 'widgets/filter_sheet.dart';
import 'widgets/labour_card.dart';
import 'widgets/search_map.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final _sheetController = DraggableScrollableController();

  late final Loadable<List<Labour>> _results = Loadable(_fetch);
  late final Loadable<List<Skill>> _skills = Loadable(
    () => context.repo.skills(),
  );

  LabourFilters _filters = const LabourFilters();
  String _search = '';
  Timer? _debounce;
  int? _selectedId;

  late final Session _session = SessionScope.read(context);
  GeoPoint? _fetchedFrom;

  @override
  void initState() {
    super.initState();
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

  Future<List<Labour>> _fetch() async {
    final origin = _origin;
    _fetchedFrom = origin;
    
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

    return _filters.applyLocal(filtered);
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
                final rows = _results.value ?? const <Labour>[];
                
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
                    _draggableList(rows),

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

  Widget _draggableList(List<Labour> rows) {
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
                padding: const EdgeInsets.only(left: Gap.xl, right: Gap.xl, bottom: Gap.md),
                child: _listHeader(rows.length),
              ),

              // List
              Expanded(
                child: _results.isInitialLoad
                    ? _skeletonList()
                    : rows.isEmpty
                        ? _emptyState()
                        : _results.error != null
                            ? _errorState()
                            : _actualList(rows, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _listHeader(int count) {
    final s = context.s;
    return Row(
      children: [
        Expanded(
          child: Text(
            _results.isInitialLoad
                ? s.searching
                : count == 0
                    ? s.noneFound
                    : s.labourFound(count),
            style: AppType.bodyStrong,
          ),
        ),
        Pressable(
          onTap: _openSort,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: 6),
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
