import 'package:flutter/material.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../widgets/pasal_card.dart';
import '../widgets/settings_drawer.dart';

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

  // Color presets (same as library_screen)
  static const List<Color> _presetColors = [
    Color(0xFFDC2626), // Red - KUHP
    Color(0xFF2563EB), // Blue - KUHAP
    Color(0xFF059669), // Emerald - ITE
    Color(0xFFD97706), // Amber - KUHPER
    Color(0xFF7C3AED), // Violet
    Color(0xFFDB2777), // Pink
    Color(0xFF0891B2), // Cyan
    Color(0xFF4F46E5), // Indigo
  ];

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

  IconData _getUUIcon(String kode) {
    final code = kode.toUpperCase().trim();
    if (code == 'KUHP') return Icons.gavel_rounded;
    if (code.contains('KUHAP')) return Icons.policy_rounded;
    if (code.contains('ITE')) return Icons.computer_rounded;
    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return Icons.people_rounded;
    }
    return Icons.menu_book_rounded;
  }

  Color _getUUColor(String kode) {
    final code = kode.toUpperCase().trim();
    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return _presetColors[3]; // Amber
    }
    if (code.contains('KUHAP')) {
      return _presetColors[1]; // Blue
    }
    if (code == 'KUHP' || code.startsWith('KUHP ')) {
      return _presetColors[0]; // Red
    }
    if (code.contains('ITE')) {
      return _presetColors[2]; // Emerald
    }
    // Generate from hash for unknown
    final hash = code.hashCode.abs();
    return _presetColors[hash % _presetColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _getUUColor(widget.undangUndang.kode);
    final icon = _getUUIcon(widget.undangUndang.kode);

    return Scaffold(
      endDrawer: const SettingsDrawer(),
      appBar: AppBar(
        title: Text(
          widget.undangUndang.kode,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: Icon(
                Icons.menu,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              tooltip: 'Pengaturan',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with icon instead of image
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Icon container instead of image
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Code badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.undangUndang.kode,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.undangUndang.nama,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.undangUndang.namaLengkap != null &&
                                    widget.undangUndang.namaLengkap!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.undangUndang.namaLengkap!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stats row
                      Row(
                        children: [
                          _buildStatBadge(
                            Icons.calendar_today_outlined,
                            'Tahun ${widget.undangUndang.tahun}',
                            isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildStatBadge(
                            Icons.article_outlined,
                            '${_allPasal.length} Pasal',
                            isDark,
                            highlight: true,
                          ),
                        ],
                      ),
                      // Show description if available
                      if (widget.undangUndang.deskripsi != null &&
                          widget.undangUndang.deskripsi!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? color.withValues(alpha: 0.1)
                                : color.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Tentang",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.undangUndang.deskripsi!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    keyboardAppearance: isDark
                        ? Brightness.dark
                        : Brightness.light,
                    onChanged: _filterLocalPasal,
                    decoration: InputDecoration(
                      hintText: "Cari dalam ${widget.undangUndang.nama}...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 20,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[400],
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _filterLocalPasal('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _searchController.text.isEmpty
                            ? 'Semua Pasal'
                            : 'Hasil Pencarian',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${_filteredPasal.length} pasal',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Pasal list
                Expanded(
                  child: _filteredPasal.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ditemukan',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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

  Widget _buildStatBadge(
    IconData icon,
    String text,
    bool isDark, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: highlight
              ? Colors.blue
              : (isDark ? Colors.grey[500] : Colors.grey[500]),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            color: highlight
                ? Colors.blue
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
