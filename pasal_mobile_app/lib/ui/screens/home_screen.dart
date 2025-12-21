import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../models/undang_undang_model.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';
import 'read_pasal_screen.dart';

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

  String _selectedFilterUUId = 'ALL';
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalPages = 1;
  bool _isSyncing = false;

  // TODO: gunakan variabel ini untuk notifikasi update data
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _checkUpdateLoop();
  }

  void _checkUpdateLoop() async {
    bool hasUpdate = await DataService.checkForUpdates();
    if (mounted && hasUpdate) {
      setState(() => _updateAvailable = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Data hukum terbaru tersedia!"),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: "UPDATE",
            textColor: Colors.white,
            onPressed: _manualSync,
          ),
          duration: const Duration(seconds: 10),
        ),
      );
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

    _applyFilterAndSearch();
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    bool success = await DataService.syncData();
    if (mounted) {
      setState(() => _isSyncing = false);
      if (success) {
        _initData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data berhasil diperbarui!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal sync."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilterAndSearch() {
    List<PasalModel> source = _allPasalCache;

    if (_selectedFilterUUId != 'ALL') {
      source = source
          .where((p) => p.undangUndangId == _selectedFilterUUId)
          .toList();
    }

    if (_searchKeyword.isNotEmpty) {
      source = source.where((p) {
        return p.nomor.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            p.isi.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
            p.keywords.any(
              (k) => k.toLowerCase().contains(_searchKeyword.toLowerCase()),
            );
      }).toList();
    }

    _filteredData = source;
    _totalPages = (_filteredData.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;

    _currentPage = 1;
    _updatePagination();
  }

  void _updatePagination() {
    setState(() {
      int startIndex = (_currentPage - 1) * _itemsPerPage;
      int endIndex = startIndex + _itemsPerPage;

      if (startIndex >= _filteredData.length) {
        _paginatedData = [];
      } else {
        if (endIndex > _filteredData.length) endIndex = _filteredData.length;
        _paginatedData = _filteredData.sublist(startIndex, endIndex);
      }
    });
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
      _updatePagination();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SizedBox(height: 4),
                      Text(
                        "Jelajahi Pasal",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _isSyncing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: _manualSync,
                          icon: const Icon(Icons.sync, color: Colors.blue),
                          tooltip: "Update Data",
                        ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  _searchKeyword = val;
                  _applyFilterAndSearch();
                },
                decoration: InputDecoration(
                  hintText: "Cari nomor pasal atau isi...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchKeyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                            _applyFilterAndSearch();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildFilterChip("Semua", 'ALL'),
                  ..._listUU
                      .map((uu) => _buildFilterChip(uu.kode, uu.id))
                      .toList(),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Pasal Terbaru",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ),
                      itemCount: _paginatedData.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _paginatedData.length) {
                          return _totalPages > 1
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: _buildPaginationFooter(),
                                )
                              : const SizedBox(height: 20);
                        }

                        final pasal = _paginatedData[index];
                        final kodeUUFuture = DataService.getKodeUU(
                          pasal.undangUndangId,
                        );
                        final String displayNomor =
                            pasal.nomor.toLowerCase().startsWith('pasal')
                            ? pasal.nomor
                            : "Pasal ${pasal.nomor}";

                        return FutureBuilder<String>(
                          future: kodeUUFuture,
                          builder: (context, snapshot) {
                            final kodeUU = snapshot.data ?? "UU";
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReadPasalScreen(
                                        pasal: pasal,
                                        contextList: _filteredData,
                                        searchQuery: _searchKeyword,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          kodeUU,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      HighlightText(
                                        text: displayNomor,
                                        query: _searchKeyword,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      HighlightText(
                                        text: pasal.isi.replaceAll('\n', ' '),
                                        query: _searchKeyword,
                                        textAlign: TextAlign.justify,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1
              ? () => _changePage(_currentPage - 1)
              : null,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_totalPages, (index) {
              int pageNum = index + 1;
              bool isActive = pageNum == _currentPage;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => _changePage(pageNum),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue : Colors.transparent,
                      border: Border.all(
                        color: isActive ? Colors.blue : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "$pageNum",
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.black,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages
              ? () => _changePage(_currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String id) {
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
        backgroundColor: Colors.white,
        selectedColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }
}
