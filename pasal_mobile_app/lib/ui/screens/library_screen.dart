import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/query_service.dart';
import '../../models/undang_undang_model.dart';
import '../../core/services/sync_manager.dart';
import 'detail_uu_screen.dart';
import '../widgets/main_layout.dart';
import '../utils/uu_color_helper.dart';

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
    // Listen for sync completion to auto-refresh data
    syncManager.state.addListener(_handleSyncStateChange);
  }

  @override
  void dispose() {
    syncManager.state.removeListener(_handleSyncStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSyncStateChange() {
    // If sync finished (went back to idle), reload data
    if (syncManager.state.value == SyncState.idle) {
      _loadData();
    }
  }

  void _loadData() async {
    await Future.delayed(const Duration(milliseconds: 100));

    final uuData = await QueryService.getAllUU();
    final pasalData = await QueryService.getAllPasal();

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

  // Get color for each UU type - delegated to centralized helper
  Color _getUUColor(String kode) {
    return UUColorHelper.getColor(kode);
  }

  // Get icon for each UU type - delegated to centralized helper
  IconData _getUUIcon(String kode) {
    return UUColorHelper.getIcon(kode);
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        "Pustaka Hukum",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                    // Hamburger menu button
                    IconButton(
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                      icon: Icon(
                        Icons.menu,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      tooltip: 'Pengaturan',
                    ),
                  ],
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
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  icon: Icons.article_rounded,
                  value: '$_totalPasal',
                  label: 'Pasal',
                  color: AppColors.secondary,
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
          color: color.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.5 : 0.3),
          ),
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
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(isDark),
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
          color: color.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.5 : 0.3),
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
                        color: AppColors.textPrimary(isDark),
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
