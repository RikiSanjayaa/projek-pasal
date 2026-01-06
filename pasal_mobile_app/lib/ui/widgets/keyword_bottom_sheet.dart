import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';

/// Bottom sheet for browsing and searching all available keywords
class KeywordBottomSheet extends StatefulWidget {
  final List<String> allKeywords;
  final List<String> selectedKeywords;
  final List<String> popularKeywords;
  final Function(String) onKeywordToggle;
  final bool autoFocus;

  const KeywordBottomSheet({
    super.key,
    required this.allKeywords,
    required this.selectedKeywords,
    required this.popularKeywords,
    required this.onKeywordToggle,
    this.autoFocus = false,
  });

  /// Show the bottom sheet and return when closed
  static Future<void> show({
    required BuildContext context,
    required List<String> allKeywords,
    required List<String> selectedKeywords,
    required List<String> popularKeywords,
    required Function(String) onKeywordToggle,
    bool autoFocus = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => KeywordBottomSheet(
        allKeywords: allKeywords,
        selectedKeywords: selectedKeywords,
        popularKeywords: popularKeywords,
        onKeywordToggle: onKeywordToggle,
        autoFocus: autoFocus,
      ),
    );
  }

  @override
  State<KeywordBottomSheet> createState() => _KeywordBottomSheetState();
}

class _KeywordBottomSheetState extends State<KeywordBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredKeywords {
    if (_searchQuery.isEmpty) {
      return widget.allKeywords;
    }
    return widget.allKeywords
        .where((k) => k.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Keyword',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                if (widget.selectedKeywords.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // Clear all selected keywords
                      for (var k in List.from(widget.selectedKeywords)) {
                        widget.onKeywordToggle(k);
                      }
                    },
                    child: const Text('Hapus Semua'),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: widget.autoFocus,
              keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari keyword...',
                hintStyle: TextStyle(color: AppColors.textSecondary(isDark)),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary(isDark),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.inputFill(isDark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: bottomPadding + 20,
              ),
              children: [
                // Active keywords section
                if (widget.selectedKeywords.isNotEmpty) ...[
                  _buildSectionHeader(
                    'AKTIF (${widget.selectedKeywords.length})',
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildKeywordChips(
                    widget.selectedKeywords,
                    isDark,
                    isSelected: true,
                  ),
                  const SizedBox(height: 16),
                ],

                // Popular keywords section (only show if not searching)
                if (_searchQuery.isEmpty &&
                    widget.popularKeywords.isNotEmpty) ...[
                  _buildSectionHeader('POPULER', isDark),
                  const SizedBox(height: 8),
                  _buildKeywordChips(
                    widget.popularKeywords
                        .where((k) => !widget.selectedKeywords.contains(k))
                        .toList(),
                    isDark,
                  ),
                  const SizedBox(height: 16),
                ],

                // All keywords section
                _buildSectionHeader(
                  _searchQuery.isEmpty
                      ? 'SEMUA (${widget.allKeywords.length})'
                      : 'HASIL PENCARIAN (${_filteredKeywords.length})',
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildKeywordChips(
                  _filteredKeywords
                      .where((k) => !widget.selectedKeywords.contains(k))
                      .toList(),
                  isDark,
                ),

                if (_filteredKeywords.isEmpty && _searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Tidak ada keyword yang cocok',
                      style: TextStyle(color: AppColors.textSecondary(isDark)),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary(isDark),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildKeywordChips(
    List<String> keywords,
    bool isDark, {
    bool isSelected = false,
  }) {
    if (keywords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keywords.map((keyword) {
        return GestureDetector(
          onTap: () => widget.onKeywordToggle(keyword),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.inputFill(isDark),
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? null
                  : Border.all(color: AppColors.border(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  keyword,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
