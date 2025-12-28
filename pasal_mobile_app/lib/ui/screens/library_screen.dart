import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';
import '../../models/undang_undang_model.dart';
import '../utils/image_helper.dart';
import 'detail_uu_screen.dart';
import '../widgets/main_layout.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<UndangUndangModel> _allUU = [];
  List<UndangUndangModel> _filteredUU = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true; 

  @override
  void initState() {
    super.initState();
    _loadUU();
  }

  void _loadUU() async {
    await Future.delayed(const Duration(milliseconds: 100)); 
    
    final data = await DataService.getAllUU();
    
    if (mounted) {
      setState(() {
        _allUU = data;
        _filteredUU = _allUU;
        _isLoading = false; 
      });
    }
  }

  void _filterBooks(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUU = _allUU;
      } else {
        _filteredUU = _allUU.where((uu) {
          return uu.kode.toLowerCase().contains(query.toLowerCase()) ||
              uu.nama.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.library_books, color: Colors.blue),
                const SizedBox(width: 10),
                Text(
                  "Pustaka Hukum",
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterBooks,
                decoration: const InputDecoration(
                  hintText: "Cari kitab undang-undang...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredUU.isEmpty
                  ? Center(child: Text("Buku tidak ditemukan", style: TextStyle(color: Colors.grey.shade500)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredUU.length,
                      itemBuilder: (context, index) {
                        final uu = _filteredUU[index];
                        final coverColor = ImageHelper.getBookColor(uu.kode);
                        final coverImage = ImageHelper.getCover(uu.kode);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => DetailUUScreen(undangUndang: uu)),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8, offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: coverColor.withOpacity(0.1),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      image: DecorationImage(image: AssetImage(coverImage), fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(uu.kode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: coverColor)),
                                        Text(
                                          uu.nama,
                                          maxLines: 2, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey.shade600, height: 1.2),
                                        ),
                                        Text("${uu.tahun}", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}