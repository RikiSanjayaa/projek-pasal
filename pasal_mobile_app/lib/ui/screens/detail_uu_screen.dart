import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';
import '../../core/services/query_service.dart';
import '../../core/services/sync_manager.dart';
import '../../core/utils/search_utils.dart';
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
        _filteredPasal = SearchUtils.rankPasal(_allPasal, query);
      }
    });
  }

  Widget _buildEmptySearchState(bool isDark) {
    final query = _searchController.text;
    final suggestions = SearchUtils.suggestionsForQuery(query);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak ditemukan',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            if (query.trim().isNotEmpty && suggestions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Coba cari dengan kata ini:',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      _searchController.text = suggestion;
                      _filterLocalPasal(suggestion);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
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
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Non-sticky Header UU Details (Scrolls away)
                  SliverToBoxAdapter(
                    child: Container(
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
                  ),

                  // Sticky Search Bar Header (Stays pinned when scrolled)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickySearchHeaderDelegate(
                      isDark: isDark,
                      searchController: _searchController,
                      undangNama: widget.undangUndang.nama,
                      filteredCount: _filteredPasal.length,
                      onChanged: _filterLocalPasal,
                      onClear: () {
                        _searchController.clear();
                        _filterLocalPasal('');
                      },
                    ),
                  ),
                ];
              },
              body: _filteredPasal.isEmpty
                  ? _buildEmptySearchState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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

class _StickySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final TextEditingController searchController;
  final String undangNama;
  final int filteredCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  _StickySearchHeaderDelegate({
    required this.isDark,
    required this.searchController,
    required this.undangNama,
    required this.filteredCount,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: searchController,
            keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: "Cari dalam $undangNama...",
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                size: 20,
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                      onPressed: onClear,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.inputFill(isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  searchController.text.isEmpty
                      ? 'Semua Pasal'
                      : 'Hasil Pencarian',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                Text(
                  '$filteredCount pasal',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 90.0;

  @override
  double get minExtent => 90.0;

  @override
  bool shouldRebuild(covariant _StickySearchHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.searchController.text != searchController.text ||
        oldDelegate.filteredCount != filteredCount;
  }
}
