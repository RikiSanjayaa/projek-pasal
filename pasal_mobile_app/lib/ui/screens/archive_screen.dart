import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import '../../core/services/archive_service.dart';
import '../../core/services/query_service.dart';
import '../../core/utils/search_utils.dart';
import '../../models/pasal_model.dart';
import '../utils/responsive_layout.dart';
import '../widgets/main_layout.dart';
import '../widgets/pasal_results_view.dart';
import '../widgets/adaptive_pasal_browser.dart';
import '../widgets/settings_drawer.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<PasalModel> _allPasalCache = [];
  List<PasalModel> _filteredData = [];
  List<PasalModel> _paginatedData = [];

  int _currentPage = 1;
  final int _itemsPerPage = 30;
  int _totalPages = 1;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final data = await QueryService.getAllPasal();
    if (mounted) {
      setState(() {
        _allPasalCache = data;
      });
      _applyFilterAndPagination();
    }
  }

  void _applyFilterAndPagination() {
    final currentArchivedIds = archiveService.archivedIds.value;

    List<PasalModel> source = _allPasalCache.where((p) {
      return currentArchivedIds.contains(p.id);
    }).toList();

    if (_searchQuery.isNotEmpty) {
      source = SearchUtils.rankPasal(source, _searchQuery);
    }

    setState(() {
      _filteredData = source;

      _totalPages = (_filteredData.length / _itemsPerPage).ceil();
      if (_totalPages == 0) _totalPages = 1;

      if (_currentPage > _totalPages) _currentPage = 1;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      child: AdaptivePasalBrowser(
        child: ValueListenableBuilder<List<String>>(
          valueListenable: archiveService.archivedIds,
          builder: (_, archivedIds, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_filteredData.length != archivedIds.length &&
                  _searchQuery.isEmpty) {
                _applyFilterAndPagination();
              }
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    MediaQuery.sizeOf(context).width < ResponsiveLayout.medium
                        ? 0
                        : 16,
                    20,
                    8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Pasal Tersimpan",
                        style: TextStyle(
                          fontSize:
                              MediaQuery.sizeOf(context).width <
                                  ResponsiveLayout.medium
                              ? 20
                              : 26,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SettingsButton(),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: TextField(
                    controller: _searchController,
                    keyboardAppearance: isDark
                        ? Brightness.dark
                        : Brightness.light,
                    onChanged: (val) {
                      _searchQuery = val;
                      _currentPage = 1;
                      _applyFilterAndPagination();
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
                                _searchController.clear();
                                _searchQuery = '';
                                _currentPage = 1;
                                _applyFilterAndPagination();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.inputFill(isDark),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchQuery.isNotEmpty
                            ? "Hasil Pencarian"
                            : "Daftar Koleksi",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Total: ${_filteredData.length}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: _filteredData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bookmark_border_rounded,
                                size: 64,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? "Tidak ditemukan."
                                    : "Belum ada pasal tersimpan.",
                                style: TextStyle(
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Ketuk ikon penanda di halaman baca pasal untuk menyimpan.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            if (scrollInfo is UserScrollNotification) {
                              FocusScope.of(context).unfocus();
                            }
                            return false;
                          },
                          child: PasalResultsView(
                            controller: _scrollController,
                            items: _paginatedData,
                            contextList: _filteredData,
                            searchQuery: _searchQuery,
                            footer: _totalPages > 1
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: _buildPaginationFooter(isDark),
                                  )
                                : const SizedBox(height: 80),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
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
                  _scrollController.jumpTo(0);
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
                  _scrollController.jumpTo(0);
                }
              : null,
        ),
      ],
    );
  }
}
