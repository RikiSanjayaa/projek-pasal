import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../models/pasal_model.dart';
import '../../models/undang_undang_model.dart';
import '../../core/services/query_service.dart';
import '../../core/utils/search_utils.dart';
import '../widgets/pasal_card.dart';
import '../widgets/main_layout.dart';
import '../widgets/update_banner.dart';
import '../widgets/keyword_bottom_sheet.dart';
import '../widgets/pagination_footer.dart';
import '../widgets/filter_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PasalModel> _allPasalCache = [];
  List<PasalModel> _filteredData = [];
  List<PasalModel> _paginatedData = [];
  List<UndangUndangModel> _listUU = [];

  List<String> _allAvailableKeywords = [];
  List<String> _popularKeywords = [];

  String _selectedFilterUUId = 'ALL';
  List<String> _selectedKeywords = [];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _filtersExpanded = false;

  static const int _visibleKeywordChipsCount = 3;

  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  final LayerLink _searchLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initData();
    _searchFocusNode.addListener(_onSearchFocusChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchFocusChange() {
    if (_searchFocusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _initData() async {
    final rawUU = await QueryService.getAllUU();
    final uniqueIds = <String>{};
    _listUU = rawUU.where((uu) => uniqueIds.add(uu.id)).toList();

    _allPasalCache = await QueryService.getAllPasal();
    _allPasalCache.sort((a, b) {
      final timeA = a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final timeB = b.updatedAt ?? b.createdAt ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });

    final Map<String, int> keywordCount = {};
    for (var p in _allPasalCache) {
      for (var k in p.keywords) {
        final trimmed = k.trim();
        if (trimmed.isNotEmpty) {
          keywordCount[trimmed] = (keywordCount[trimmed] ?? 0) + 1;
        }
      }
    }

    _allAvailableKeywords = keywordCount.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final sortedByUsage = keywordCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _popularKeywords = sortedByUsage.take(15).map((e) => e.key).toList();

    _applyFilterAndSearch();
  }

  Future<void> _handleSyncComplete() async {
    _initData();
  }

  void _toggleKeyword(String keyword) {
    setState(() {
      if (_selectedKeywords.contains(keyword)) {
        _selectedKeywords.remove(keyword);
      } else {
        _selectedKeywords.add(keyword);
      }
      _applyFilterAndSearch();
    });
  }

  void _removeKeyword(String val) {
    setState(() {
      _selectedKeywords.remove(val);
      _applyFilterAndSearch();
    });
  }

  void _applyFilterAndSearch() {
    List<PasalModel> source = _allPasalCache;

    if (_selectedFilterUUId != 'ALL') {
      source = source
          .where((p) => p.undangUndangId == _selectedFilterUUId)
          .toList();
    }

    if (_selectedKeywords.isNotEmpty) {
      source = source.where((p) {
        return _selectedKeywords.every(
          (selectedK) => p.keywords.any(
            (pasalK) => pasalK.toLowerCase() == selectedK.toLowerCase(),
          ),
        );
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();

      final nomorQuery = SearchUtils.extractNomorQuery(q);

      source = source.where((p) {
        final nomorMatch =
            p.nomor.toLowerCase().contains(nomorQuery) ||
            'pasal ${p.nomor}'.toLowerCase().contains(q);

        final contentMatch = p.isi.toLowerCase().contains(q);
        final titleMatch =
            p.judul != null && p.judul!.toLowerCase().contains(q);

        return nomorMatch || contentMatch || titleMatch;
      }).toList();

      if (SearchUtils.isNomorSearch(q)) {
        source = SearchUtils.sortByNomorRelevance(
          source,
          nomorQuery,
          (p) => p.nomor,
        );
      }
    }

    setState(() {
      _filteredData = source;
      _totalPages = (_filteredData.length / _itemsPerPage).ceil();
      if (_totalPages == 0) _totalPages = 1;
      _currentPage = 1;
      _updatePagination();
    });
  }

  void _updatePagination() {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredData.length) {
      _paginatedData = [];
    } else {
      if (endIndex > _filteredData.length) endIndex = _filteredData.length;
      _paginatedData = _filteredData.sublist(startIndex, endIndex);
    }
  }

  List<String> _getKeywordSuggestions() {
    if (_searchQuery.isEmpty) {
      return _popularKeywords
          .where((k) => !_selectedKeywords.contains(k))
          .take(5)
          .toList();
    }

    final q = _searchQuery.toLowerCase();
    return _allAvailableKeywords
        .where(
          (k) => k.toLowerCase().contains(q) && !_selectedKeywords.contains(k),
        )
        .take(5)
        .toList();
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSearchSuggestionsOverlay(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildSearchSuggestionsOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keywordSuggestions = _getKeywordSuggestions();

    // Only show overlay when user is typing (Match Screenshot behavior)
    // Remove "Popular Keywords" (Zero State) as requested
    if (_searchQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    if (keywordSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      width: MediaQuery.of(context).size.width - 40,
      child: CompositedTransformFollower(
        link: _searchLayerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 50),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card(isDark),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard and overlay when tapping outside
          _searchFocusNode.unfocus();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UpdateBanner(onSyncComplete: _handleSyncComplete),

            _buildHeader(isDark),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: CompositedTransformTarget(
                link: _searchLayerLink,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  keyboardAppearance: isDark
                      ? Brightness.dark
                      : Brightness.light,
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilterAndSearch();
                    _updateOverlay();
                  },
                  decoration: InputDecoration(
                    hintText: "Cari nomor, nama atau isi pasal...",
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _searchQuery = '';
                              _applyFilterAndSearch();
                              _updateOverlay();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.inputFill(isDark),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            ActiveFiltersSection(
              selectedKeywords: _selectedKeywords,
              selectedUUName: _selectedFilterUUId != 'ALL'
                  ? _listUU
                        .where((u) => u.id == _selectedFilterUUId)
                        .firstOrNull
                        ?.kode
                  : null,
              onClearAll: () {
                setState(() {
                  _selectedKeywords.clear();
                  _selectedFilterUUId = 'ALL';
                  _applyFilterAndSearch();
                });
              },
              onRemoveUU: () {
                setState(() {
                  _selectedFilterUUId = 'ALL';
                  _applyFilterAndSearch();
                });
              },
              onRemoveKeyword: (keyword) => _removeKeyword(keyword),
            ),

            _buildFilterSections(isDark),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    (_searchQuery.isNotEmpty || _selectedKeywords.isNotEmpty)
                        ? "Pasal yang sesuai"
                        : "Pasal Terbaru",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Total: ${_filteredData.length}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _paginatedData.isEmpty
                  ? const Center(child: Text("Data tidak ditemukan."))
                  : ListView.builder(
                      controller: _listScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _paginatedData.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _paginatedData.length) {
                          return _totalPages > 1
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: PaginationFooter(
                                    currentPage: _currentPage,
                                    totalPages: _totalPages,
                                    onPrevious: () {
                                      setState(() {
                                        _currentPage--;
                                        _updatePagination();
                                      });
                                      _listScrollController.jumpTo(0);
                                    },
                                    onNext: () {
                                      setState(() {
                                        _currentPage++;
                                        _updatePagination();
                                      });
                                      _listScrollController.jumpTo(0);
                                    },
                                  ),
                                )
                              : const SizedBox(height: 20);
                        }

                        return PasalCard(
                          pasal: _paginatedData[index],
                          contextList: _filteredData,
                          searchQuery: _searchQuery,
                          showUULabel: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Jelajahi Pasal",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          // Hamburger menu button
          IconButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: Icon(
              Icons.menu,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            tooltip: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSections(bool isDark) {
    final hasAnyFilters =
        _allAvailableKeywords.isNotEmpty || _listUU.isNotEmpty;

    if (!hasAnyFilters) return const SizedBox.shrink();

    final blueColor = AppColors.primary;
    final bgColor = AppColors.card(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Toggle
          InkWell(
            onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            borderRadius: _filtersExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: _filtersExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(12),
                border: _filtersExpanded
                    ? Border(
                        bottom: BorderSide(
                          color: blueColor.withValues(alpha: 0.8),
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: _filtersExpanded
                        ? blueColor
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _filtersExpanded
                            ? blueColor
                            : (isDark ? Colors.grey[200] : Colors.grey[700]),
                      ),
                    ),
                  ),
                  if (_selectedKeywords.isNotEmpty ||
                      _selectedFilterUUId != 'ALL')
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: blueColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_selectedKeywords.length + (_selectedFilterUUId != 'ALL' ? 1 : 0)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _filtersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _filtersExpanded
                          ? blueColor
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content body
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutQuart,
              alignment: Alignment.topCenter,
              heightFactor: _filtersExpanded ? 1.0 : 0.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _filtersExpanded ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      // Keywords section
                      _buildKeywordChipsRow(isDark),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                      ),

                      // UU section
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 13,
                              color: blueColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Undang-Undang',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildUUChip("Semua", 'ALL', isDark),
                            ..._listUU
                                .map(
                                  (uu) => _buildUUChip(uu.kode, uu.id, isDark),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUUChip(String label, String id, bool isDark) {
    final bool isSelected = _selectedFilterUUId == id;
    final blueColor = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilterUUId = id;
            _applyFilterAndSearch();
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? blueColor : AppColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? blueColor
                  : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeywordChipsRow(bool isDark) {
    final displayKeywords = _popularKeywords
        .where((k) => !_selectedKeywords.contains(k))
        .take(_visibleKeywordChipsCount)
        .toList();

    final remainingCount =
        _allAvailableKeywords.length -
        _selectedKeywords.length -
        displayKeywords.length;

    if (displayKeywords.isEmpty && remainingCount <= 0) {
      return const SizedBox.shrink();
    }

    final blueColor = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 14, color: blueColor),
              const SizedBox(width: 8),
              Text(
                'Keywords',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _showKeywordBottomSheet(autoFocus: true),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card(isDark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                      ),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: blueColor,
                    ),
                  ),
                ),
              ),

              ...displayKeywords.map(
                (keyword) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _toggleKeyword(keyword),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card(isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (remainingCount > 0)
                InkWell(
                  onTap: () => _showKeywordBottomSheet(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: blueColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: blueColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '+$remainingCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showKeywordBottomSheet({bool autoFocus = false}) {
    KeywordBottomSheet.show(
      context: context,
      allKeywords: _allAvailableKeywords,
      selectedKeywords: _selectedKeywords,
      popularKeywords: _popularKeywords,
      autoFocus: autoFocus,
      onKeywordToggle: (keyword) {
        _toggleKeyword(keyword);
        Navigator.of(context).pop();
        _showKeywordBottomSheet(autoFocus: autoFocus);
      },
    );
  }
}
