import 'package:flutter/material.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/image_helper.dart';
import '../widgets/pasal_card.dart'; 

class DetailUUScreen extends StatefulWidget {
  final UndangUndangModel undangUndang;
  const DetailUUScreen({super.key, required this.undangUndang});

  @override
  State<DetailUUScreen> createState() => _DetailUUScreenState();
}

class _DetailUUScreenState extends State<DetailUUScreen> {
  List<PasalModel> _allPasal = [];
  List<PasalModel> _filteredPasal = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPasal();
  }

  void _loadPasal() async {
    final pasal = await DataService.getPasalByUU(widget.undangUndang.id);
    setState(() {
      _allPasal = pasal;
      _filteredPasal = _allPasal;
      _isLoading = false;
    });
  }

  void _filterLocalPasal(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPasal = _allPasal;
      } else {
        _filteredPasal = _allPasal.where((p) {
          return p.nomor.toLowerCase().contains(query.toLowerCase()) ||
              p.isi.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.undangUndang.kode, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  color: isDark ? Colors.grey[900] : Colors.white,
                  child: Row(
                    children: [
                      Container(
                        width: 50, height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          image: DecorationImage(
                            image: AssetImage(ImageHelper.getCover(widget.undangUndang.kode)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.undangUndang.nama, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            Text("Tahun ${widget.undangUndang.tahun}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text("${_allPasal.length} Pasal", style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterLocalPasal,
                    decoration: InputDecoration(
                      hintText: "Cari dalam buku ini...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredPasal.length,
                    itemBuilder: (context, index) {
                      return PasalCard(
                        pasal: _filteredPasal[index],
                        contextList: _filteredPasal, 
                        searchQuery: _searchController.text,
                        showUULabel: false, 
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}