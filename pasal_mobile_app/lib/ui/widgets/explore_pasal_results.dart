import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/search_utils.dart';
import '../../models/pasal_model.dart';
import '../utils/responsive_layout.dart';
import 'adaptive_pasal_browser.dart';
import 'pagination_footer.dart';
import 'pasal_results_view.dart';

/// Owns paging and its layout-dependent defaults, not the opening result order.
class ExplorePasalResults extends StatefulWidget {
  const ExplorePasalResults({
    super.key,
    required this.items,
    required this.controller,
    required this.searchQuery,
    this.searchResult,
  });

  final List<PasalModel> items;
  final ScrollController controller;
  final String searchQuery;
  final SearchResult? searchResult;

  @override
  State<ExplorePasalResults> createState() => _ExplorePasalResultsState();
}

class _ExplorePasalResultsState extends State<ExplorePasalResults> {
  static const _preferenceKey = 'explore_pasal_items_per_page';
  static const _pageSizes = [10, 20, 30, 50];

  late final Future<SharedPreferences> _preferences;
  int? _pageSizeOverride;
  bool _preferenceChanged = false;
  int _automaticPageSize = 10;
  int _firstItem = 0;
  int _browseFirstItem = 0;
  double? _browseOffset;
  String? _selectedPasalId;
  String? _leadingItemId;
  String? _revealItemId;
  int _visibleStart = -1;
  int _visibleEnd = -1;
  List<PasalModel> _visibleItems = const [];

  int get _pageSize => _pageSizeOverride ?? _automaticPageSize;

  @override
  void initState() {
    super.initState();
    _preferences = SharedPreferences.getInstance();
    unawaited(_loadPreference());
  }

  Future<void> _loadPreference() async {
    final preferences = await _preferences;
    final saved = preferences.getInt(_preferenceKey);
    if (!mounted || _preferenceChanged || !_pageSizes.contains(saved)) return;
    setState(() => _pageSizeOverride = saved);
  }

  @override
  void didUpdateWidget(ExplorePasalResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _firstItem = 0;
      _browseFirstItem = 0;
      _browseOffset = null;
      _leadingItemId = null;
      _revealItemId = null;
      _visibleStart = -1;
      _restoreScroll(0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final selected = AdaptivePasalBrowser.selectedPasalIdOf(context);
    final desktop =
        MediaQuery.sizeOf(context).width >= ResponsiveLayout.expanded;
    final previousSize = _pageSize;
    _automaticPageSize = desktop && selected == null ? 30 : 10;
    double? restoreOffset;
    if (selected != _selectedPasalId) {
      _revealItemId = null;
      if (selected != null) {
        if (_selectedPasalId == null) {
          _browseFirstItem = _firstItem;
          _browseOffset = widget.controller.hasClients
              ? widget.controller.offset
              : null;
        }
        final index = widget.items.indexWhere((item) => item.id == selected);
        if (index >= 0) _firstItem = index;
        restoreOffset = 0;
      } else {
        _firstItem = _browseFirstItem;
        restoreOffset = _browseOffset;
        _browseOffset = null;
      }
      _selectedPasalId = selected;
    } else if (_pageSize != previousSize) {
      final index = widget.items.indexWhere(
        (item) => item.id == _leadingItemId,
      );
      if (index >= 0) _firstItem = index;
      _revealItemId = index >= 0 ? _leadingItemId : null;
      if (_revealItemId == null) restoreOffset = 0;
    }
    if (restoreOffset != null) _restoreScroll(restoreOffset);
  }

  void _restoreScroll(double offset) {
    final selection = _selectedPasalId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _selectedPasalId == selection &&
          widget.controller.hasClients) {
        widget.controller.jumpTo(
          offset.clamp(0, widget.controller.position.maxScrollExtent),
        );
      }
    });
  }

  Future<void> _setPageSize(int value) async {
    setState(() {
      _preferenceChanged = true;
      _pageSizeOverride = value == 0 ? null : value;
      _leadingItemId = null;
      _revealItemId = null;
      _browseOffset = null;
    });
    _restoreScroll(0);
    final preferences = await _preferences;
    if (value == 0) {
      await preferences.remove(_preferenceKey);
    } else {
      await preferences.setInt(_preferenceKey, value);
    }
  }

  void _goTo(int firstItem) {
    setState(() {
      _firstItem = firstItem;
      _leadingItemId = null;
      _revealItemId = null;
    });
    _restoreScroll(0);
  }

  @override
  Widget build(BuildContext context) {
    final size = _pageSize;
    final totalPages = widget.items.isEmpty
        ? 1
        : (widget.items.length + size - 1) ~/ size;
    final currentPage = (_firstItem ~/ size + 1).clamp(1, totalPages);
    final start = (currentPage - 1) * size;
    final end = (start + size).clamp(0, widget.items.length);
    if (_visibleStart != start || _visibleEnd != end) {
      _visibleItems = widget.items.sublist(start, end);
      _visibleStart = start;
      _visibleEnd = end;
    }
    return PasalResultsView(
      controller: widget.controller,
      items: _visibleItems,
      contextList: widget.items,
      searchQuery: widget.searchQuery,
      searchResult: widget.searchResult,
      onLeadingItemChanged: (id) {
        _leadingItemId = id;
        _revealItemId = null;
      },
      revealItemId: _revealItemId,
      footer: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Per halaman',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11),
                    ),
                    DropdownButton<int>(
                      value: _pageSizeOverride ?? 0,
                      isDense: true,
                      isExpanded: true,
                      style: DefaultTextStyle.of(context).style,
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(
                            'Otomatis ($_automaticPageSize)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final option in _pageSizes)
                          DropdownMenuItem(
                            value: option,
                            child: Text('$option'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) unawaited(_setPageSize(value));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            PaginationFooter(
              currentPage: currentPage,
              totalPages: totalPages,
              onPrevious: () => _goTo(start - size),
              onNext: () => _goTo(end),
            ),
          ],
        ),
      ),
    );
  }
}
