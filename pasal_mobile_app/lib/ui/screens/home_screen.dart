import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../models/undang_undang_model.dart';
import '../../core/services/data_service.dart';
import '../widgets/pasal_card.dart';
import '../widgets/main_layout.dart';
import '../widgets/update_banner.dart';
import '../widgets/keyword_bottom_sheet.dart';

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
  List<String> _popularKeywords = []; // Top keywords by usage
  Map<String, int> _keywordUsageCount = {}; // Keyword -> pasal count

  String _selectedFilterUUId = 'ALL';
  List<String> _selectedKeywords = [];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Collapsible filter state
  bool _filtersExpanded = false;

  // How many keyword chips to show before [+N]
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
    final rawUU = await DataService.getAllUU();
    final uniqueIds = <String>{};
    _listUU = rawUU.where((uu) => uniqueIds.add(uu.id)).toList();

    _allPasalCache = await DataService.getAllPasal();
    _allPasalCache.sort((a, b) {
      final timeA = a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final timeB = b.updatedAt ?? b.createdAt ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });

    // Count keyword usage and collect all keywords
    final Map<String, int> keywordCount = {};
    for (var p in _allPasalCache) {
      for (var k in p.keywords) {
        final trimmed = k.trim();
        if (trimmed.isNotEmpty) {
          keywordCount[trimmed] = (keywordCount[trimmed] ?? 0) + 1;
        }
      }
    }

    _keywordUsageCount = keywordCount;
    _allAvailableKeywords = keywordCount.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // Get popular keywords (top N by usage)
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

      // Handle "pasal X" search pattern - extract just the number/identifier
      String nomorQuery = q;
      if (q.startsWith('pasal ')) {
        nomorQuery = q.substring(6).trim(); // Remove "pasal " prefix
      }

      source = source.where((p) {
        // Match nomor: "pasal 1" should find nomor "1", "1A", etc.
        final nomorMatch =
            p.nomor.toLowerCase().contains(nomorQuery) ||
            'pasal ${p.nomor}'.toLowerCase().contains(q);

        // Match content and title
        final contentMatch = p.isi.toLowerCase().contains(q);
        final titleMatch =
            p.judul != null && p.judul!.toLowerCase().contains(q);

        return nomorMatch || contentMatch || titleMatch;
      }).toList();
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

  // Get keyword suggestions based on search query
  List<String> _getKeywordSuggestions() {
    if (_searchQuery.isEmpty) {
      // Show popular keywords when search is empty
      return _popularKeywords
          .where((k) => !_selectedKeywords.contains(k))
          .take(5)
          .toList();
    }

    // Filter keywords by search query
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

    // Don't show overlay if no suggestions
    if (keywordSuggestions.isEmpty && _searchQuery.isEmpty) {
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
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Keyword suggestions section
                  if (keywordSuggestions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'KEYWORD POPULER'
                            : 'KEYWORD COCOK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...keywordSuggestions.map(
                      (keyword) => InkWell(
                        onTap: () {
                          _toggleKeyword(keyword);
                          _updateOverlay();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tag,
                                size: 16,
                                color: isDark ? Colors.grey[500] : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  keyword,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '${_keywordUsageCount[keyword] ?? 0} pasal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Hint to search in content
                  if (_searchQuery.isNotEmpty) ...[
                    InkWell(
                      onTap: () {
                        _searchFocusNode.unfocus();
                        _removeOverlay();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Cari "'),
                                    TextSpan(
                                      text: _searchQuery,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const TextSpan(text: '" di isi pasal'),
                                  ],
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
            // Update banner
            UpdateBanner(onSyncComplete: _handleSyncComplete),

            // Header
            _buildHeader(isDark),

            // Search bar with overlay
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
                    hintText: "Cari pasal atau keyword...",
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
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            // Active filters summary (shows when any filter is active)
            _buildActiveFiltersSection(isDark),

            // Filter sections container
            _buildFilterSections(isDark),

            // Results header
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

            // Results list
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
                                  child: _buildPaginationFooter(isDark),
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

  /// Builds the header section with title and hamburger menu
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

  /// Builds the active filters section showing selected keywords and UU
  Widget _buildActiveFiltersSection(bool isDark) {
    final hasActiveKeywords = _selectedKeywords.isNotEmpty;
    final hasActiveUU = _selectedFilterUUId != 'ALL';

    if (!hasActiveKeywords && !hasActiveUU) {
      return const SizedBox.shrink();
    }

    // Find selected UU name
    String? selectedUUName;
    if (hasActiveUU) {
      final uu = _listUU.where((u) => u.id == _selectedFilterUUId).firstOrNull;
      selectedUUName = uu?.kode;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blue.withValues(alpha: 0.15)
            : Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with clear all button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 14, color: Colors.blue[400]),
                  const SizedBox(width: 6),
                  Text(
                    'Filter Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[400],
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedKeywords.clear();
                    _selectedFilterUUId = 'ALL';
                    _applyFilterAndSearch();
                  });
                },
                child: Text(
                  'Hapus Semua',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Active filter chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Selected UU chip
              if (hasActiveUU && selectedUUName != null)
                _buildActiveFilterChip(
                  label: selectedUUName,
                  icon: Icons.menu_book,
                  onRemove: () {
                    setState(() {
                      _selectedFilterUUId = 'ALL';
                      _applyFilterAndSearch();
                    });
                  },
                  isDark: isDark,
                ),

              // Selected keyword chips
              ..._selectedKeywords.map(
                (k) => _buildActiveFilterChip(
                  label: k,
                  icon: Icons.tag,
                  onRemove: () => _removeKeyword(k),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// Builds a refined, unified, and compact filter section
  Widget _buildFilterSections(bool isDark) {
    final hasAnyFilters =
        _allAvailableKeywords.isNotEmpty || _listUU.isNotEmpty;

    if (!hasAnyFilters) return const SizedBox.shrink();

    final blueColor = Colors.blue;
    final bgColor = isDark ? Colors.grey[850] : Colors.white;

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
    final blueColor = Colors.blue;

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
            color: isSelected
                ? blueColor
                : (isDark ? Colors.grey[850] : Colors.grey[50]),
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
    // Get keywords to display (popular, excluding already selected)
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

    final blueColor = Colors.blue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
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
        // Chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Search button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _showKeywordBottomSheet(autoFocus: true),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
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

              // Keyword chips
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
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
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

              // [+N] button to open bottom sheet
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
        // Force rebuild of bottom sheet
        Navigator.of(context).pop();
        _showKeywordBottomSheet(autoFocus: autoFocus);
      },
    );
  }

  Widget _buildPaginationFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                    _updatePagination();
                  });
                  // Scroll to top after page change
                  _listScrollController.jumpTo(0);
                }
              : null,
        ),
        Text("$_currentPage / $_totalPages"),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                    _updatePagination();
                  });
                  // Scroll to top after page change
                  _listScrollController.jumpTo(0);
                }
              : null,
        ),
      ],
    );
  }
}
