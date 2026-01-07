import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';

/// Active filter chip showing a single active filter with remove option
class ActiveFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onRemove;

  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Section showing all currently active filters
class ActiveFiltersSection extends StatelessWidget {
  final List<String> selectedKeywords;
  final String? selectedUUName;
  final VoidCallback onClearAll;
  final VoidCallback onRemoveUU;
  final void Function(String keyword) onRemoveKeyword;

  const ActiveFiltersSection({
    super.key,
    required this.selectedKeywords,
    this.selectedUUName,
    required this.onClearAll,
    required this.onRemoveUU,
    required this.onRemoveKeyword,
  });

  bool get _hasFilters => selectedKeywords.isNotEmpty || selectedUUName != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasFilters) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 14,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onClearAll,
                child: Text(
                  'Hapus Semua',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (selectedUUName != null)
                ActiveFilterChip(
                  label: selectedUUName!,
                  icon: Icons.menu_book,
                  onRemove: onRemoveUU,
                ),
              ...selectedKeywords.map(
                (k) => ActiveFilterChip(
                  label: k,
                  icon: Icons.tag,
                  onRemove: () => onRemoveKeyword(k),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selectable chip widget for filters
class SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SelectableChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blueColor = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? blueColor : AppColors.card(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? blueColor
                  : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }
}
