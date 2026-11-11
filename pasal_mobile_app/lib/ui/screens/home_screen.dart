import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/services/pdf_export_service.dart';
import '../../core/config/app_colors.dart';
import '../../models/pasal_model.dart';
import '../../models/undang_undang_model.dart';
import '../../core/services/query_service.dart';
import '../../core/utils/search_utils.dart';
import '../../core/utils/bab_utils.dart';
import '../utils/responsive_layout.dart';
import '../widgets/explore_pasal_results.dart';
import '../widgets/search_tier_header.dart';
import '../widgets/main_layout.dart';
import '../widgets/bab_bottom_sheet.dart';
import '../widgets/filter_widgets.dart';
import '../widgets/interactive_surface.dart';

import 'package:showcaseview/showcaseview.dart';

import '../widgets/app_showcase.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/adaptive_pasal_browser.dart';
import '../widgets/settings_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();

  List<PasalModel> _allPasalCache = [];
  List<PasalModel> _filteredData = [];
  List<UndangUndangModel> _listUU = [];
  List<BabGroup> _allBabGroups = [];

  /// Bab yang tersedia untuk filter, sesuai filter UU aktif.
  List<BabGroup> _babGroups = [];

  String _selectedFilterUUId = 'ALL';
  BabGroup? _selectedBab;
  String? _selectedBabJudul;

  String _searchQuery = '';

  /// Kueri yang benar-benar dipakai: sama dengan [_searchQuery], atau hasil koreksi
  /// ejaan ([_correctedQuery]) kalau kueri asli tidak menemukan apa pun.
  String _effectiveQuery = '';
  String? _correctedQuery;

  /// Hasil pencarian terakhir, untuk judul kelompok (frasa persis, semua kata, sebagian).
  SearchResult? _searchResult;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _filtersExpanded = false;

  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _initData() async {
    await _loadPasalData();

    final prefs = await SharedPreferences.getInstance();
    bool hasShownShowcase = prefs.getBool('has_shown_home_showcase') ?? false;
    if (!hasShownShowcase) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              ShowcaseView.get().startShowCase([_searchKey, _filterKey]);
              prefs.setBool('has_shown_home_showcase', true);
            }
          });
        }
      });
    }
  }

  Future<void> _loadPasalData() async {
    final rawUU = await QueryService.getAllUU();
    final uniqueIds = <String>{};
    final listUU = rawUU.where((uu) => uniqueIds.add(uu.id)).toList();

    final allPasal = await QueryService.getAllPasal();
    allPasal.sort((a, b) {
      final timeA = a.updatedAt ?? a.createdAt ?? DateTime(2000);
      final timeB = b.updatedAt ?? b.createdAt ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });

    final babGroups = BabUtils.groupsOf(
      allPasal,
      uuOrder: listUU.map((u) => u.id).toList(),
    );

    if (!mounted) return;
    setState(() {
      _listUU = listUU;
      _allPasalCache = allPasal;
      _allBabGroups = babGroups;
      _refreshBabGroups();
    });

    _applyFilterAndSearch();
  }

  /// Bab yang ditawarkan: semua UU, atau hanya UU yang dipilih.
  void _refreshBabGroups() {
    _babGroups = _selectedFilterUUId == 'ALL'
        ? _allBabGroups
        : _allBabGroups
              .where((g) => g.undangUndangId == _selectedFilterUUId)
              .toList();
    // Objek grup dibuat ulang saat data dimuat ulang; cocokkan lewat UU dan bab.
    final selected = _selectedBab;
    if (selected != null) {
      _selectedBab = _babGroups
          .where(
            (g) =>
                g.undangUndangId == selected.undangUndangId &&
                g.bab == selected.bab,
          )
          .firstOrNull;
      if (_selectedBab == null) _selectedBabJudul = null;
    }
  }

  void _selectUU(String id) {
    setState(() {
      _selectedFilterUUId = id;
      _refreshBabGroups();
      _applyFilterAndSearch();
    });
  }

  void _removeBab() {
    setState(() {
      _selectedBab = null;
      _selectedBabJudul = null;
      _applyFilterAndSearch();
    });
  }

  String? get _selectedBabLabel {
    final bab = _selectedBab;
    if (bab == null) return null;
    final judul = _selectedBabJudul;
    return judul == null ? bab.bab : '${bab.bab}${BabUtils.separator}$judul';
  }

  void _applyFilterAndSearch() {
    List<PasalModel> source = _allPasalCache;

    if (_selectedFilterUUId != 'ALL') {
      source = source
          .where((p) => p.undangUndangId == _selectedFilterUUId)
          .toList();
    }

    final bab = _selectedBab;
    if (bab != null) {
      source = source
          .where(
            (p) => BabUtils.matches(
              p,
              bab.undangUndangId,
              bab.bab,
              _selectedBabJudul,
            ),
          )
          .toList();
      if (_searchQuery.isEmpty) {
        source.sort((a, b) => QueryService.compareNomor(a.nomor, b.nomor));
      }
    }

    String? corrected;
    SearchResult? result;
    if (_searchQuery.isNotEmpty) {
      final kodeByUuId = {for (final uu in _listUU) uu.id: uu.kode};
      final filtered = source;
      result = SearchUtils.search(
        filtered,
        _searchQuery,
        kodeByUuId: kodeByUuId,
      );
      // Ada kata yang tidak muncul di data sama sekali (biasanya salah ketik): pakai
      // kueri hasil koreksi kalau kueri itu menemukan pasal.
      final candidate = SearchUtils.correctQuery(
        _searchQuery,
        _allPasalCache,
        kodeByUuId: kodeByUuId,
      );
      if (candidate != null) {
        final correctedResult = SearchUtils.search(
          filtered,
          candidate,
          kodeByUuId: kodeByUuId,
        );
        if (correctedResult.pasal.isNotEmpty) {
          corrected = candidate;
          result = correctedResult;
        }
      }
      source = result.pasal;
    }

    setState(() {
      _correctedQuery = corrected;
      _searchResult = result;
      _effectiveQuery = corrected ?? _searchQuery;
      _filteredData = source;
    });
  }

  Widget _buildEmptySearchState(bool isDark) {
    final suggestions = SearchUtils.suggestionsForQuery(_searchQuery);
    final dataSuggestions = SearchUtils.suggestionsFromData(
      _searchQuery,
      _allPasalCache,
    );
    final hasSuggestions = suggestions.isNotEmpty || dataSuggestions.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              "Data tidak ditemukan.",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.trim().isNotEmpty && hasSuggestions) ...[
              const SizedBox(height: 14),
              Text(
                "Coba cari dengan kata ini:",
                style: TextStyle(
                  color: AppColors.textSecondary(isDark),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...suggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(suggestion),
                      onPressed: () {
                        _searchQuery = suggestion;
                        _searchController.text = suggestion;
                        _applyFilterAndSearch();
                      },
                    );
                  }),
                  ...dataSuggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(suggestion),
                      onPressed: () {
                        _searchQuery = suggestion;
                        _searchController.text = suggestion;
                        _applyFilterAndSearch();
                      },
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      onSyncComplete: _loadPasalData,
      child: AdaptivePasalBrowser(
        child: GestureDetector(
          onTap: () {
            _searchFocusNode.unfocus();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: AppColors.appBar(isDark),
                foregroundDecoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border(isDark)),
                  ),
                ),
                child: _buildHeader(isDark),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.sizeOf(context).width < ResponsiveLayout.medium
                      ? 8
                      : 24,
                  20,
                  5,
                ),
                child: AppShowcase(
                  showcaseKey: _searchKey,
                  title: 'Cari Pasal',
                  description: 'Ketik untuk mencari pasal berdasarkan:\n\n• Nomor pasal (contoh: "Pasal 1")\n• Judul pasal\n• Isi konten pasal\n\nHasil akan langsung ditampilkan saat Anda mengetik.',
                  shapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    keyboardAppearance: isDark
                        ? Brightness.dark
                        : Brightness.light,
                    onChanged: (val) {
                      _searchQuery = val;
                      // Peringkat dihitung ulang setelah jeda mengetik, bukan tiap huruf.
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 250),
                        _applyFilterAndSearch,
                      );
                    },
                    decoration: InputDecoration(
                      hintText: "Cari nomor, nama atau isi pasal...",
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary(isDark),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _searchController.clear();
                                _searchQuery = '';
                                _applyFilterAndSearch();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.inputFill(isDark),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              ActiveFiltersSection(
                selectedBabLabel: _selectedBabLabel,
                selectedUUName: _selectedFilterUUId != 'ALL'
                    ? _listUU
                          .where((u) => u.id == _selectedFilterUUId)
                          .firstOrNull
                          ?.kode
                    : null,

                onClearAll: () {
                  setState(() {
                    _selectedBab = null;
                    _selectedBabJudul = null;
                    _selectedFilterUUId = 'ALL';
                    _refreshBabGroups();
                    _applyFilterAndSearch();
                  });
                },

                onRemoveUU: () {
                  setState(() {
                    _selectedFilterUUId = 'ALL';
                    _refreshBabGroups();
                    _applyFilterAndSearch();
                  });
                },

                onRemoveBab: _removeBab,
              ),
              AppShowcase(
                showcaseKey: _filterKey,
                title: 'Filter Pencarian',
                description: 'Persempit hasil pencarian dengan memilih:\n\n• Bab - bagian tertentu dari undang-undang\n• Undang-Undang - sumber hukum tertentu\n\nKombinasi filter menghasilkan pencarian lebih akurat.',
                shapeBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildFilterSections(isDark),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_searchQuery.isNotEmpty || _selectedBab != null)
                                ? "${_filteredData.length} pasal terkait ditemukan"
                                : "Pasal Terbaru",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (_correctedQuery != null)
                            Text(
                              'Menampilkan hasil untuk "$_correctedQuery"',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                          if (SearchTierHeader.noPhraseNotice(_searchResult)
                              case final notice?)
                            Text(
                              notice,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_searchQuery.isNotEmpty &&
                        _filteredData.isNotEmpty) ...[
                      InteractiveSurface(
                        onTap: () {
                          PdfExportService.exportBatchPasal(
                            pasalList: _filteredData,
                            searchQuery: _effectiveQuery,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        showBorder: false,
                        color: Color.alphaBlend(
                          AppColors.primary.withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ),
                          AppColors.scaffold(isDark),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 8.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 20,
                                color: AppColors.accent(isDark),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Cetak PDF",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        "Total: ${_filteredData.length}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: _filteredData.isEmpty
                    ? _buildEmptySearchState(isDark)
                    : ExplorePasalResults(
                        controller: _listScrollController,
                        items: _filteredData,
                        searchQuery: _effectiveQuery,
                        searchResult: _searchResult,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      constraints: BoxConstraints(
        minHeight: MediaQuery.sizeOf(context).width < ResponsiveLayout.medium
            ? 48
            : kToolbarHeight,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.sizeOf(context).width < ResponsiveLayout.medium ? 0 : 16,
        20,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Jelajahi Pasal",
            style: TextStyle(
              fontSize:
                  MediaQuery.sizeOf(context).width < ResponsiveLayout.medium
                  ? 20
                  : 26,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SettingsButton(),
        ],
      ),
    );
  }

  Widget _buildFilterSections(bool isDark) {
    if (_allBabGroups.isEmpty && _listUU.isEmpty)
      return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, panelConstraints) {
        // Keep 700 px for the two filter columns plus their 40 px page inset.
        final wide = panelConstraints.maxWidth >= 740;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide)
                InteractiveSurface(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.tune_rounded, size: 18),
                    title: const Text('Filter'),
                    trailing: Icon(
                      _filtersExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ),
              if (wide || _filtersExpanded)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final laws = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Undang-Undang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          runSpacing: 8,
                          children: [
                            _buildUUChip('Semua', 'ALL', isDark),
                            for (final uu in _listUU)
                              _buildUUChip(uu.kode, uu.id, isDark),
                          ],
                        ),
                      ],
                    );
                    return Padding(
                      padding: EdgeInsets.only(top: wide ? 0 : 12),
                      child: constraints.maxWidth >= 700
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: laws),
                                const SizedBox(width: 24),
                                Expanded(child: _buildBabRow(isDark)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                laws,
                                const SizedBox(height: 12),
                                _buildBabRow(isDark),
                              ],
                            ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUUChip(String label, String id, bool isDark) => SelectableChip(
    label: label,
    isSelected: _selectedFilterUUId == id,
    onTap: () => _selectUU(id),
  );

  Widget _buildBabRow(bool isDark) {
    if (_babGroups.isEmpty) return const SizedBox.shrink();

    final blueColor = AppColors.accent(isDark);
    final label = _selectedBabLabel ?? 'Pilih bab (${_babGroups.length})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 14, color: blueColor),
              const SizedBox(width: 8),
              Text(
                'Bab',
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
        InteractiveSurface(
          onTap: _showBabBottomSheet,
          borderRadius: BorderRadius.circular(12),
          selected: _selectedBab != null,
          borderColor: _selectedBab != null ? blueColor : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.icon(isDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showBabBottomSheet() {
    BabBottomSheet.show(
      context: context,
      groups: _babGroups,
      kodeByUuId: {for (final uu in _listUU) uu.id: uu.kode},
      groupByUU: _selectedFilterUUId == 'ALL',
      onSelected: (group, judul) {
        setState(() {
          _selectedBab = group;
          _selectedBabJudul = judul;
          _applyFilterAndSearch();
        });
      },
    );
  }
}
