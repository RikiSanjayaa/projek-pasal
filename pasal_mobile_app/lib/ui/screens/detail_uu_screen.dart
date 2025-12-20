import 'package:flutter/material.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/image_helper.dart';
import 'read_pasal_screen.dart'; 

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

  @override
  void initState() {
    super.initState();
    _allPasal = DataService.getPasalByUU(widget.undangUndang.id);
    _filteredPasal = _allPasal;
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
    final primaryColor = ImageHelper.getBookColor(widget.undangUndang.kode);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.undangUndang.kode, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            color: Colors.white,
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
                      Text(widget.undangUndang.nama, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Tahun ${widget.undangUndang.tahun}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("${_allPasal.length} Pasal", style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLocalPasal,
              decoration: InputDecoration(
                hintText: "Cari kata kunci dalam buku ini...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredPasal.length,
              separatorBuilder: (c, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final pasal = _filteredPasal[index];
                final int nomorUrut = index + 1;
                
                final String displayNomor = pasal.nomor.toLowerCase().startsWith('pasal') 
                    ? pasal.nomor 
                    : "Pasal ${pasal.nomor}";

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReadPasalScreen(
                          pasal: pasal, 
                          searchQuery: _searchController.text,
                          contextList: _filteredPasal 
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "$nomorUrut", 
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayNomor, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pasal.isi,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
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