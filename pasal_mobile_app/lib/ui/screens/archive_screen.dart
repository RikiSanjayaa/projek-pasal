import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/archive_service.dart';
import '../../core/services/data_service.dart';
import '../../core/utils/search_utils.dart';
import '../../models/pasal_model.dart';
import '../widgets/main_layout.dart';
import '../widgets/pasal_card.dart';
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
  final int _itemsPerPage = 10;
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
    final data = await DataService.getAllPasal();
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
      endDrawer: const SettingsDrawer(),
      child: ValueListenableBuilder<List<String>>(
        valueListenable: archiveService.archivedIds,
        builder: (context, archivedIds, child) {
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_filteredData.length != archivedIds.length && _searchQuery.isEmpty) {
              _applyFilterAndPagination();
            }
          });
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pasal Tersimpan",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        return IconButton(
                          onPressed: () {
                            Scaffold.of(context).openEndDrawer();
                          },
                          icon: Icon(
                            Icons.menu,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                          tooltip: 'Pengaturan',
                        );
                      }
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    _searchQuery = val;
                    _currentPage = 1; 
                    _applyFilterAndPagination();
                  },
                  decoration: InputDecoration(
                    hintText: "Cari judul, nomor, atau isi...",
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                              color: isDark ? Colors.grey[700] : Colors.grey[300]
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty 
                                ? "Tidak ditemukan." 
                                : "Belum ada pasal tersimpan.",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
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
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _paginatedData.length + 1, 
                          itemBuilder: (context, index) {
                            
                            if (index == _paginatedData.length) {
                               return _filteredData.length > _itemsPerPage 
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: _buildPaginationFooter(isDark),
                                    ) 
                                  : const SizedBox(height: 80);
                            }
                            
                            final pasal = _paginatedData[index];
                            return PasalCard(
                              pasal: pasal,
                              contextList: _filteredData,
                              searchQuery: _searchQuery,
                              showUULabel: true,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
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