import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../../core/services/query_service.dart';
import '../../core/services/sync_manager.dart';
import '../widgets/pasal_card.dart';
import '../widgets/settings_drawer.dart';
import '../utils/uu_color_helper.dart';

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
    syncManager.state.addListener(_handleSyncStateChange);
  }

  @override
  void dispose() {
    syncManager.state.removeListener(_handleSyncStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSyncStateChange() {
    if (syncManager.state.value == SyncState.idle) {
      _loadPasal();
    }
  }

  void _loadPasal() async {
    final pasal = await QueryService.getPasalByUU(widget.undangUndang.id);
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
    return UUColorHelper.getIcon(kode);
  }

  Color _getUUColor(String kode) {
    return UUColorHelper.getColor(kode);
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
              icon: Icon(Icons.menu, color: AppColors.icon(isDark)),
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
                    color: AppColors.card(isDark),
                    border: Border(
                      bottom: BorderSide(color: AppColors.border(isDark)),
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
                              color: color.withValues(
                                alpha: isDark ? 0.1 : 0.05,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withValues(
                                  alpha: isDark ? 0.5 : 0.3,
                                ),
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
                                    color: AppColors.textPrimary(isDark),
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
                                        color: AppColors.textSecondary(isDark),
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
                            color: color.withValues(alpha: isDark ? 0.1 : 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(
                                alpha: isDark ? 0.5 : 0.3,
                              ),
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
                      fillColor: AppColors.inputFill(isDark),
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
              ? AppColors.primary
              : (isDark ? Colors.grey[500] : Colors.grey[500]),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            color: highlight
                ? AppColors.primary
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}
