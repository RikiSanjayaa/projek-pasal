import 'package:material_ui/material_ui.dart';

import '../../core/config/app_colors.dart';
import '../../core/utils/date_format_id.dart';
import '../../core/utils/word_diff.dart';
import '../../models/pasal_model.dart';
import '../../models/pasal_versi_model.dart';
import '../utils/open_link.dart';
import 'law_content_formatter.dart';
import 'pasal_sections.dart';

Color _statusColor(String status, bool isDark) {
  switch (status) {
    case PasalVersiModel.statusDiubah:
      return isDark ? Colors.orange[300]! : Colors.orange[900]!;
    case PasalVersiModel.statusDisisipkan:
      return isDark ? Colors.green[300]! : Colors.green[800]!;
    case PasalVersiModel.statusDihapus:
      return isDark ? Colors.red[300]! : Colors.red[800]!;
    default:
      return isDark ? Colors.blue[300]! : Colors.blue[800]!;
  }
}

/// Chip di header pasal, contoh "Diubah UU 1/2026". Tidak tampil untuk pasal
/// tanpa riwayat atau yang versi terakhirnya masih 'asli'.
class PasalRiwayatChip extends StatelessWidget {
  final List<PasalVersiModel> versi;

  const PasalRiwayatChip({super.key, required this.versi});

  @override
  Widget build(BuildContext context) {
    if (versi.isEmpty) return const SizedBox.shrink();
    final latest = versi.last;
    if (latest.status == PasalVersiModel.statusAsli) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor(latest.status, isDark);
    final sumber = latest.sumber?.trim() ?? '';
    final label = sumber.isEmpty
        ? latest.statusLabel
        : '${latest.statusLabel} $sumber';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 13, color: color),
          const SizedBox(width: 4),
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
    );
  }
}

/// Kartu "Riwayat perubahan". Disembunyikan oleh pemanggil bila pasal belum
/// punya riwayat (lebih sepi daripada kartu "Belum ada perubahan" di hampir
/// semua pasal).
class RiwayatPasalEntry extends StatelessWidget {
  final List<PasalVersiModel> versi;
  final VoidCallback onTap;

  const RiwayatPasalEntry({super.key, required this.versi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latest = versi.last;
    final sumber = latest.sumber?.trim() ?? '';
    final subtitle = sumber.isEmpty
        ? '${versi.length} versi'
        : '${versi.length} versi · terakhir $sumber';

    return Material(
      color: AppColors.card(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(isDark)),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat perubahan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showRiwayatPasalSheet(
  BuildContext context, {
  required PasalModel pasal,
  required String kodeUU,
  required List<PasalVersiModel> versi,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => RiwayatPasalSheet(
        pasal: pasal,
        kodeUU: kodeUU,
        versi: versi,
        scrollController: controller,
      ),
    ),
  );
}

class RiwayatPasalSheet extends StatefulWidget {
  final PasalModel pasal;
  final String kodeUU;
  final List<PasalVersiModel> versi;
  final ScrollController? scrollController;

  const RiwayatPasalSheet({
    super.key,
    required this.pasal,
    required this.kodeUU,
    required this.versi,
    this.scrollController,
  });

  @override
  State<RiwayatPasalSheet> createState() => _RiwayatPasalSheetState();
}

class _RiwayatPasalSheetState extends State<RiwayatPasalSheet> {
  late int _selected;
  bool _showDiff = true;
  final Map<int, List<DiffSegment>> _isiDiffCache = {};
  final Map<int, List<DiffSegment>?> _penjelasanDiffCache = {};

  @override
  void initState() {
    super.initState();
    _selected = widget.versi.length - 1;
  }

  List<DiffSegment> _isiDiff(int index) {
    return _isiDiffCache.putIfAbsent(
      index,
      () => diffLegalTexts(
        widget.versi[index - 1].isi,
        widget.versi[index].isi,
      ),
    );
  }

  /// Diff penjelasan hanya bila kedua versi punya penjelasan; selain itu
  /// penjelasan ditampilkan apa adanya.
  List<DiffSegment>? _penjelasanDiff(int index) {
    return _penjelasanDiffCache.putIfAbsent(index, () {
      final before = widget.versi[index - 1].penjelasan?.trim() ?? '';
      final after = widget.versi[index].penjelasan?.trim() ?? '';
      if (before.isEmpty || after.isEmpty) return null;
      return diffLegalTexts(before, after);
    });
  }

  Future<void> _openLink(String url) => openExternalLink(context, url);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versi = widget.versi;
    final current = versi[_selected];
    final hasPrevious = _selected > 0;
    final diffOn = hasPrevious && _showDiff;
    final textColor = isDark ? Colors.grey[200] : const Color(0xFF333333);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Riwayat perubahan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.kodeUU} Pasal ${widget.pasal.nomor} · ${versi.length} versi',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(isDark),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < versi.length; i++) ...[
          _VersiTile(
            versi: versi[i],
            isLatest: i == versi.length - 1,
            selected: i == _selected,
            onTap: () => setState(() => _selected = i),
            onOpenLink: versi[i].naskahResmi?.trim().isNotEmpty == true
                ? () => _openLink(versi[i].naskahResmi!.trim())
                : null,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'ISI PASAL · ${current.statusLabel.toUpperCase()}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (hasPrevious) ...[
              Text(
                'Tandai perubahan',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              Switch(
                value: _showDiff,
                onChanged: (v) => setState(() => _showDiff = v),
              ),
            ],
          ],
        ),
        if (diffOn) ...[
          _DiffLegend(isDark: isDark),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        diffOn
            ? LawContentFormatter.diff(
                key: ValueKey('isi-diff-$_selected'),
                segments: _isiDiff(_selected),
                fontSize: 16,
                height: 1.8,
                color: textColor,
              )
            : LawContentFormatter(
                key: ValueKey('isi-$_selected'),
                content: current.isi,
                fontSize: 16,
                height: 1.8,
                color: textColor,
              ),
        if ((current.penjelasan?.trim().length ?? 0) > 3) ...[
          const SizedBox(height: 24),
          if (diffOn && _penjelasanDiff(_selected) != null)
            _PenjelasanDiff(
              key: ValueKey('penjelasan-diff-$_selected'),
              segments: _penjelasanDiff(_selected)!,
            )
          else
            PenjelasanSection(
              key: ValueKey('penjelasan-$_selected'),
              penjelasan: current.penjelasan!,
            ),
        ],
      ],
    );
  }
}

class _VersiTile extends StatelessWidget {
  final PasalVersiModel versi;
  final bool isLatest;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpenLink;

  const _VersiTile({
    required this.versi,
    required this.isLatest,
    required this.selected,
    required this.onTap,
    this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(versi.status, isDark);
    final sub = AppColors.textSecondary(isDark);
    final sumber = versi.sumber?.trim() ?? '';
    final judul = versi.judulSumber?.trim() ?? '';
    final diundangkan = versi.diundangkanDate;
    final berlaku = versi.berlakuSejakDate;
    final dates = [
      if (diundangkan != null) 'Diundangkan ${DateFormatId.short(diundangkan)}',
      if (berlaku != null) 'Berlaku sejak ${DateFormatId.short(berlaku)}',
    ].join(' · ');

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06)
          : AppColors.card(isDark),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.border(isDark),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Tag(label: versi.statusLabel, color: statusColor),
                        if (isLatest)
                          _Tag(
                            label: 'Berlaku',
                            color: isDark
                                ? Colors.green[300]!
                                : Colors.green[800]!,
                            filled: true,
                          )
                        else
                          _Tag(label: 'Tidak berlaku lagi', color: sub),
                      ],
                    ),
                    if (sumber.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        sumber,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                    if (judul.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        judul,
                        style: TextStyle(fontSize: 12, color: sub, height: 1.3),
                      ),
                    ],
                    if (dates.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(dates, style: TextStyle(fontSize: 11, color: sub)),
                    ],
                  ],
                ),
              ),
              if (onOpenLink != null)
                IconButton(
                  tooltip: 'Buka naskah resmi',
                  icon: Icon(Icons.open_in_new_rounded, size: 20, color: sub),
                  onPressed: onOpenLink,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _Tag({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DiffLegend extends StatelessWidget {
  final bool isDark;

  const _DiffLegend({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark));
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Dibanding versi sebelumnya:', style: style),
        Text(
          'dihapus',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.diffRemoved(isDark),
            backgroundColor: AppColors.diffRemovedBg(isDark),
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.diffRemoved(isDark),
          ),
        ),
        Text(
          'ditambahkan',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.diffInserted(isDark),
            backgroundColor: AppColors.diffInsertedBg(isDark),
            decoration: TextDecoration.underline,
            decorationColor: AppColors.diffInserted(isDark),
          ),
        ),
      ],
    );
  }
}

class _PenjelasanDiff extends StatelessWidget {
  final List<DiffSegment> segments;

  const _PenjelasanDiff({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.5 : 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PENJELASAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          LawContentFormatter.diff(
            segments: segments,
            fontSize: 15,
            height: 1.7,
            color: AppColors.textSecondary(isDark),
          ),
        ],
      ),
    );
  }
}
