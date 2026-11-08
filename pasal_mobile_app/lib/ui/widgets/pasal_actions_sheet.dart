import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';

/// Satu aksi di lembar "Aksi pasal".
class PasalAction {
  final IconData icon;
  final String label;
  final String? description;
  final Color? color;
  final VoidCallback onTap;

  const PasalAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
    this.color,
  });
}

/// Lembar bawah berisi semua aksi untuk satu pasal (simpan, salin, PDF, naskah resmi, riwayat).
/// Lembar ditutup dulu, baru aksi dijalankan, supaya notifikasi tampil di layar pasal.
Future<void> showPasalActionsSheet(
  BuildContext context, {
  required String title,
  required List<PasalAction> actions,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final muted = isDark ? Colors.grey[400] : Colors.grey[600];
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
              ),
            ),
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon, color: action.color ?? AppColors.textPrimary(isDark)),
                title: Text(
                  action.label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary(isDark)),
                ),
                subtitle: action.description == null
                    ? null
                    : Text(action.description!, style: TextStyle(fontSize: 12, color: muted)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onTap();
                },
              ),
          ],
        ),
      );
    },
  );
}
