import 'package:flutter/material.dart';

import '../../core/config/app_colors.dart';
import '../../core/utils/date_format_id.dart';
import '../../models/pasal_model.dart';

/// Chip kecil untuk daftar pasal. Hanya tampil jika pasal belum diverifikasi.
class UnverifiedChip extends StatelessWidget {
  const UnverifiedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.orange[300]! : Colors.orange[900]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            'Belum diverifikasi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok status verifikasi di layar baca pasal.
class VerificationStatusBlock extends StatelessWidget {
  final PasalModel pasal;
  final String? officialUrl;
  final VoidCallback? onOpenOfficial;

  const VerificationStatusBlock({
    super.key,
    required this.pasal,
    this.officialUrl,
    this.onOpenOfficial,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (pasal.isVerified) {
      final label = pasal.verifiedAt != null
          ? 'Terverifikasi admin · ${DateFormatId.short(pasal.verifiedAt!)}'
          : 'Terverifikasi admin';
      final color = isDark ? Colors.green[300]! : Colors.green[800]!;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final accent = isDark ? Colors.orange[300]! : Colors.orange[900]!;
    final hasUrl = officialUrl != null && officialUrl!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Belum diverifikasi admin',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Teks diambil dari kompilasi tidak resmi. Cocokkan dengan naskah resmi sebelum dijadikan rujukan.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          if (hasUrl) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onOpenOfficial,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.link_rounded, size: 16),
              label: const Text(
                'Buka naskah resmi',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
