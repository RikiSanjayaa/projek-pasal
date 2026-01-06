import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/data_service.dart';
import '../widgets/settings_drawer.dart';

class KeywordResultScreen extends StatelessWidget {
  final String keyword;

  const KeywordResultScreen({super.key, required this.keyword});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(isDark),
      endDrawer: const SettingsDrawer(),
      appBar: AppBar(
        title: Text(keyword),
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
      body: FutureBuilder<List>(
        future: DataService.getPasalByKeyword(keyword),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "Tidak ada pasal dengan tag '$keyword'",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            );
          }

          final results = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final pasal = results[index];

              return FutureBuilder<String>(
                future: DataService.getKodeUU(pasal.undangUndangId),
                builder: (context, kodeSnapshot) {
                  final kodeUU = kodeSnapshot.data ?? "UU";

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: AppColors.card(isDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.border(isDark)),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        "$kodeUU - ${pasal.nomor}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      subtitle: Text(
                        pasal.isi,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            pasal.isi,
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              height: 1.5,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                        if (pasal.keywords.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Wrap(
                              spacing: 8,
                              children: pasal.keywords.map((k) {
                                final isActive =
                                    k.toLowerCase() == keyword.toLowerCase();
                                return Chip(
                                  label: Text(
                                    k,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isActive
                                          ? Colors.white
                                          : Colors.blue,
                                    ),
                                  ),
                                  backgroundColor: isActive
                                      ? Colors.blue
                                      : AppColors.card(isDark),
                                  side: BorderSide(
                                    color: isActive
                                        ? Colors.transparent
                                        : (isDark
                                              ? Colors.blue.shade700
                                              : Colors.blue.shade100),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
