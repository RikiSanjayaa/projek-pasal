import 'package:flutter/material.dart';
import '../../core/services/data_service.dart';
import '../../models/undang_undang_model.dart';
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
  Map<String, int> _pasalCounts = {}; // UU ID -> pasal count
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  int _totalPasal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() async {
    await Future.delayed(const Duration(milliseconds: 100));

    final uuData = await DataService.getAllUU();
    final pasalData = await DataService.getAllPasal();

    // Count pasal per UU
    final Map<String, int> counts = {};
    for (var pasal in pasalData) {
      counts[pasal.undangUndangId] = (counts[pasal.undangUndangId] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _allUU = uuData;
        _filteredUU = _allUU;
        _pasalCounts = counts;
        _totalPasal = pasalData.length;
        _isLoading = false;
      });
    }
  }

  // 8 preset colors for UU types (expandable for future)
  static const List<Color> _presetColors = [
    Color(0xFFDC2626), // Red - KUHP
    Color(0xFF2563EB), // Blue - KUHAP
    Color(0xFF059669), // Emerald - ITE
    Color(0xFFD97706), // Amber - KUHPER
    Color(0xFF7C3AED), // Violet - Reserved
    Color(0xFFDB2777), // Pink - Reserved
    Color(0xFF0891B2), // Cyan - Reserved
    Color(0xFF4F46E5), // Indigo - Reserved
  ];

  // Extra colors for random assignment (beyond 8 preset)
  static const List<Color> _extraColors = [
    Color(0xFF059669), // Teal
    Color(0xFFCA8A04), // Yellow
    Color(0xFF9333EA), // Purple
    Color(0xFFE11D48), // Rose
    Color(0xFF0D9488), // Teal
    Color(0xFFEA580C), // Orange
  ];

  // Cache for dynamically assigned colors
  final Map<String, Color> _dynamicColorCache = {};
  int _nextColorIndex = 4; // Start after known UU colors

  // Get icon for each UU type
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

  // Get color for each UU type - with dynamic assignment for new UU
  Color _getUUColor(String kode) {
    final code = kode.toUpperCase().trim();

    // Check known UU types first (order matters!)
    // KUHPER/PERDATA must be checked BEFORE KUHP (since KUHPER contains KUHP)
    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return _presetColors[3]; // Amber
    }
    if (code.contains('KUHAP')) {
      return _presetColors[1]; // Blue
    }
    if (code == 'KUHP' || code.startsWith('KUHP ')) {
      return _presetColors[0]; // Red - exact match to avoid matching KUHPER
    }
    if (code.contains('ITE')) {
      return _presetColors[2]; // Emerald
    }

    // Check if already assigned dynamically
    if (_dynamicColorCache.containsKey(code)) {
      return _dynamicColorCache[code]!;
    }

    // Assign new color dynamically
    Color newColor;
    if (_nextColorIndex < _presetColors.length) {
      // Use remaining preset colors
      newColor = _presetColors[_nextColorIndex];
      _nextColorIndex++;
    } else {
      // Use extra colors pool, or generate from hash
      final extraIndex =
          (_nextColorIndex - _presetColors.length) % _extraColors.length;
      if (extraIndex < _extraColors.length) {
        newColor = _extraColors[extraIndex];
      } else {
        // Generate deterministic color from hash
        final hash = code.hashCode;
        newColor = Color.fromARGB(
          255,
          (hash & 0xFF0000) >> 16,
          (hash & 0x00FF00) >> 8,
          hash & 0x0000FF,
        ).withValues(alpha: 1.0);
      }
      _nextColorIndex++;
    }

    _dynamicColorCache[code] = newColor;
    return newColor;
  }

  // Get gradient for card
  List<Color> _getCardGradient(String kode, bool isDark) {
    final baseColor = _getUUColor(kode);
    if (isDark) {
      return [
        baseColor.withValues(alpha: 0.1),
        baseColor.withValues(alpha: 0.1),
      ];
    }
    return [
      baseColor.withValues(alpha: 0.1),
      baseColor.withValues(alpha: 0.05),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MainLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Pustaka Hukum",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Koleksi peraturan perundang-undangan Indonesia",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _buildStatCard(
                  icon: Icons.auto_stories_rounded,
                  value: '${_allUU.length}',
                  label: 'Sumber',
                  color: Colors.blue,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.article_rounded,
                  value: '$_totalPasal',
                  label: 'Pasal',
                  color: Colors.green,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Semua Undang-Undang",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                Text(
                  "${_filteredUU.length} tersedia",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // UU List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUU.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: _filteredUU.length,
                    itemBuilder: (context, index) {
                      final uu = _filteredUU[index];
                      return _buildUUCard(uu, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUUCard(UndangUndangModel uu, bool isDark) {
    final color = _getUUColor(uu.kode);
    final icon = _getUUIcon(uu.kode);
    final pasalCount = _pasalCounts[uu.id] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailUUScreen(undangUndang: uu),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getCardGradient(uu.kode, isDark),
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code badge + Year
                    Row(
                      children: [
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
                            uu.kode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tahun ${uu.tahun}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Name
                    Text(
                      uu.nama,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.grey[800],
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stats row
                    Row(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pasalCount Pasal',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        if (uu.deskripsi != null &&
                            uu.deskripsi!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ada deskripsi',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "Tidak ada hasil",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Coba kata kunci lain",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
