import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import 'interactive_surface.dart';

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
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Hapus filter $label',
            child: InteractiveSurface(
              onTap: onRemove,
              selected: true,
              color: AppColors.primary,
              showBorder: false,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section showing all currently active filters
class ActiveFiltersSection extends StatelessWidget {
  final String? selectedBabLabel;
  final String? selectedUUName;
  final VoidCallback onClearAll;
  final VoidCallback onRemoveUU;
  final VoidCallback onRemoveBab;

  const ActiveFiltersSection({
    super.key,
    this.selectedBabLabel,
    this.selectedUUName,
    required this.onClearAll,
    required this.onRemoveUU,
    required this.onRemoveBab,
  });

  bool get _hasFilters => selectedBabLabel != null || selectedUUName != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasFilters) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.selected(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
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
                    color: AppColors.accent(isDark),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent(isDark),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  'Hapus Semua',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.accent(isDark),
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
              if (selectedBabLabel != null)
                ActiveFilterChip(
                  label: selectedBabLabel!,
                  icon: Icons.account_tree_outlined,
                  onRemove: onRemoveBab,
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
      child: InteractiveSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        selected: isSelected,
        color: isSelected ? blueColor : null,
        borderColor: isSelected ? blueColor : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
