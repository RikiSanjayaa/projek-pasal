import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../models/undang_undang_model.dart';
import '../../core/services/data_service.dart';
import '../../core/services/sync_manager.dart';
import '../../core/config/theme_controller.dart';
import '../widgets/pasal_card.dart';
import '../widgets/main_layout.dart';
import '../widgets/update_banner.dart';

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

  String _selectedFilterUUId = 'ALL';
  List<String> _selectedKeywords = [];

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _autocompleteController = TextEditingController();
  final FocusNode _autocompleteFocusNode = FocusNode();

  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _autocompleteController.dispose();
    _autocompleteFocusNode.dispose();
    super.dispose();
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

    final Set<String> keywordSet = {};
    for (var p in _allPasalCache) {
      for (var k in p.keywords) {
        keywordSet.add(k.trim());
      }
    }
    _allAvailableKeywords = keywordSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    _applyFilterAndSearch();
  }

  Future<void> _handleSyncComplete() async {
    // Reload data after sync completes
    _initData();
  }

  void _addKeyword(String val) {
    if (val.trim().isEmpty) return;

    List<String> tags = val.split(',');

    setState(() {
      for (var tag in tags) {
        final cleanTag = tag.trim();
        final isExist = _selectedKeywords.any(
          (k) => k.toLowerCase() == cleanTag.toLowerCase(),
        );

        if (cleanTag.isNotEmpty && !isExist) {
          _selectedKeywords.add(cleanTag);
        }
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
      final q = _searchQuery.toLowerCase();
      source = source.where((p) {
        return p.nomor.toLowerCase().contains(q) ||
            p.isi.toLowerCase().contains(q) ||
            (p.judul != null && p.judul!.toLowerCase().contains(q));
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Update banner - shows when updates are available
          UpdateBanner(onSyncComplete: _handleSyncComplete),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Jelajahi Pasal",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Last sync info
                    if (syncManager.lastSyncTime != null)
                      Text(
                        "Diperbarui: ${syncManager.lastSyncText}",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      onPressed: themeController.toggle,
                    ),
                    // Sync status indicator and manual sync button
                    ValueListenableBuilder<SyncState>(
                      valueListenable: syncManager.state,
                      builder: (context, state, child) {
                        if (state == SyncState.syncing || state == SyncState.checking) {
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return IconButton(
                          onPressed: () async {
                            final hasUpdate = await syncManager.forceCheckUpdates();
                            if (mounted && !hasUpdate) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Data sudah up-to-date"),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.sync, color: Colors.blue),
                          tooltip: "Periksa update",
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _applyFilterAndSearch();
              },
              decoration: InputDecoration(
                hintText: "Cari nomor, judul, atau isi...",
                prefixIcon: const Icon(Icons.search),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RawAutocomplete<String>(
                  textEditingController: _autocompleteController,
                  focusNode: _autocompleteFocusNode,

                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _allAvailableKeywords.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    _addKeyword(selection);
                    _autocompleteController.clear();
                  },
                  fieldViewBuilder:
                      (context, textController, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          onSubmitted: (String value) {
                            _addKeyword(value);
                            textController.clear();
                          },
                          decoration: InputDecoration(
                            hintText: "Filter berdasarkan kata kunci/keywords",
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            prefixIcon: const Icon(
                              Icons.tag,
                              size: 16,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[900]
                                : Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 300,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 16,
                                        color: isDark
                                            ? Colors.grey
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (_selectedKeywords.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: _selectedKeywords
                          .map(
                            (k) => Chip(
                              label: Text(
                                k,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.blue,
                              deleteIcon: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                              onDeleted: () => _removeKeyword(k),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
            child: Row(
              children: [
                _buildFilterChip("Semua", 'ALL', isDark),
                ..._listUU
                    .map((uu) => _buildFilterChip(uu.kode, uu.id, isDark))
                    .toList(),
              ],
            ),
          ),

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
    );
  }

  Widget _buildPaginationFooter(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left),
          onPressed: _currentPage > 1
              ? () => setState(() {
                  _currentPage--;
                  _updatePagination();
                })
              : null,
        ),
        Text("$_currentPage / $_totalPages"),
        IconButton(
          icon: Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages
              ? () => setState(() {
                  _currentPage++;
                  _updatePagination();
                })
              : null,
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String id, bool isDark) {
    final bool isSelected = _selectedFilterUUId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          _selectedFilterUUId = id;
          _applyFilterAndSearch();
        },
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        selectedColor: Colors.blue,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[300] : Colors.black),
        ),
      ),
    );
  }
}
