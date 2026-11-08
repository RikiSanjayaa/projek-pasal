import 'package:material_ui/material_ui.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/query_service.dart';
import '../../models/pasal_model.dart';
import '../widgets/pasal_card.dart';
import '../widgets/settings_drawer.dart';

/// Daftar pasal dalam satu bab di satu undang-undang, urut nomor.
class BabResultScreen extends StatelessWidget {
  final String undangUndangId;
  final String bab;

  const BabResultScreen({
    super.key,
    required this.undangUndangId,
    required this.bab,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      endDrawer: const SettingsDrawer(),
      appBar: AppBar(
        title: Text(bab, style: const TextStyle(fontSize: 16)),
        elevation: 0,
        backgroundColor: AppColors.appBar(isDark),
        foregroundColor: AppColors.textPrimary(isDark),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              icon: Icon(
                Icons.menu,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              tooltip: 'Pengaturan',
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<PasalModel>>(
        future: QueryService.getPasalByBab(undangUndangId, bab),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final results = snapshot.data ?? const <PasalModel>[];
          if (results.isEmpty) {
            return Center(
              child: Text(
                'Tidak ada pasal di bab ini',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) => PasalCard(
              pasal: results[index],
              contextList: results,
              showUULabel: false,
            ),
          );
        },
      ),
    );
  }
}
