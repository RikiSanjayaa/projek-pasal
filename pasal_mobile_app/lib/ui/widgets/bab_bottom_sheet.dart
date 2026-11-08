import 'package:material_ui/material_ui.dart';
import '../../core/config/app_colors.dart';
import '../../core/utils/bab_utils.dart';
import '../../core/utils/search_utils.dart';

/// Bottom sheet dua tingkat: pilih bab, lalu (opsional) pilih judul di bab itu.
class BabBottomSheet extends StatefulWidget {
  final List<BabGroup> groups;

  /// Kode UU per id UU, untuk judul kelompok.
  final Map<String, String> kodeByUuId;

  /// Tampilkan judul kelompok per UU (saat filter UU "Semua").
  final bool groupByUU;
  final void Function(BabGroup group, String? judul) onSelected;

  const BabBottomSheet({
    super.key,
    required this.groups,
    required this.kodeByUuId,
    required this.groupByUU,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required List<BabGroup> groups,
    required Map<String, String> kodeByUuId,
    required bool groupByUU,
    required void Function(BabGroup group, String? judul) onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: BabBottomSheet(
          groups: groups,
          kodeByUuId: kodeByUuId,
          groupByUU: groupByUU,
          onSelected: (group, judul) {
            Navigator.of(context).pop();
            onSelected(group, judul);
          },
        ),
      ),
    );
  }

  @override
  State<BabBottomSheet> createState() => _BabBottomSheetState();
}

class _BabBottomSheetState extends State<BabBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  BabGroup? _picked;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BabGroup> get _visibleGroups {
    final q = SearchUtils.normalize(_searchQuery);
    if (q.isEmpty) return widget.groups;
    return widget.groups
        .where((g) => SearchUtils.normalize(g.bab).contains(q))
        .toList();
  }

  void _pick(BabGroup group) {
    if (group.juduls.isEmpty) {
      widget.onSelected(group, null);
    } else {
      setState(() => _picked = group);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: _picked == null
                ? _buildBabStep(isDark)
                : _buildJudulStep(_picked!, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBabStep(bool isDark) {
    final groups = _visibleGroups;
    final children = <Widget>[];
    String? lastUU;
    for (final g in groups) {
      if (widget.groupByUU && g.undangUndangId != lastUU) {
        lastUU = g.undangUndangId;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              (widget.kodeByUuId[g.undangUndangId] ?? 'UU').toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(isDark),
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }
      children.add(
        _row(
          title: g.bab,
          count: g.count,
          trailing: g.juduls.isEmpty ? null : Icons.chevron_right_rounded,
          isDark: isDark,
          onTap: () => _pick(g),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Pilih Bab',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(isDark),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari bab...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: AppColors.inputFill(isDark),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border(isDark)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada bab yang cocok',
                    style: TextStyle(color: AppColors.textSecondary(isDark)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: children,
                ),
        ),
      ],
    );
  }

  Widget _buildJudulStep(BabGroup group, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _picked = null),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Kembali',
              ),
              Expanded(
                child: Text(
                  group.bab,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              _row(
                title: 'Semua pasal di bab ini',
                count: group.count,
                isDark: isDark,
                onTap: () => widget.onSelected(group, null),
              ),
              ...group.juduls.map(
                (j) => _row(
                  title: j.judul,
                  count: j.count,
                  isDark: isDark,
                  onTap: () => widget.onSelected(group, j.judul),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row({
    required String title,
    required int count,
    required bool isDark,
    required VoidCallback onTap,
    IconData? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$count pasal',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            if (trailing != null)
              Icon(trailing, size: 18, color: AppColors.textSecondary(isDark)),
          ],
        ),
      ),
    );
  }
}
