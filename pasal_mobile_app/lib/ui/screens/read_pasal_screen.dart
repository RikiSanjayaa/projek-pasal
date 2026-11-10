import 'package:material_ui/material_ui.dart';

import 'dart:async';

import '../../core/config/app_colors.dart';

import 'package:flutter/services.dart';

import '../../models/pasal_model.dart';
import '../../core/services/query_service.dart';
import '../utils/highlight_text.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/law_content_formatter.dart';
import '../utils/uu_color_helper.dart';
import '../../core/services/archive_service.dart';
import '../widgets/app_notification.dart';
import '../widgets/pasal_sections.dart';

import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/pdf_export_service.dart';
import '../widgets/app_showcase.dart';
import '../utils/open_link.dart';
import '../widgets/riwayat_pasal.dart';
import '../../core/services/data_service.dart';
import '../../models/pasal_versi_model.dart';
import '../widgets/pasal_actions_sheet.dart';
import 'bab_result_screen.dart';
import '../utils/responsive_layout.dart';

class ReadPasalScreen extends StatefulWidget {
  final PasalModel pasal;
  final String searchQuery;
  final List<PasalModel>? contextList;
  final VoidCallback? onBack;

  const ReadPasalScreen({
    super.key,
    required this.pasal,
    this.searchQuery = '',
    this.contextList,
    this.onBack,
  });

  @override
  State<ReadPasalScreen> createState() => _ReadPasalScreenState();
}

class _ReadPasalScreenState extends State<ReadPasalScreen> {
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _actionsKey = GlobalKey();
  String? _kodeUU;
  String? _officialUrl;
  late PasalModel _currentPasal;
  List<PasalVersiModel> _versi = [];
  final ScrollController _scrollController = ScrollController();
  List<PasalModel> _chapterPasal = [];
  Map<String, List<PasalModel>> _chapters = {};
  String? _chapterUUId;

  bool _isSearching = false;
  late TextEditingController _searchController;
  late String _localSearchQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      // v1 memperkenalkan tombol simpan/salin/PDF yang terpisah; v2 = satu tombol aksi.
      final shownV1 = prefs.getBool('has_shown_read_pasal_showcase') ?? false;
      final shownV2 =
          prefs.getBool('has_shown_read_pasal_showcase_v2') ?? false;

      if (!shownV2 && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ShowcaseView.get().startShowCase([
              if (!shownV1) _searchKey,
              _actionsKey,
            ]);
            prefs.setBool('has_shown_read_pasal_showcase', true);
            prefs.setBool('has_shown_read_pasal_showcase_v2', true);
          }
        });
      }
    });
    _currentPasal = widget.pasal;
    _localSearchQuery = widget.searchQuery;
    _searchController = TextEditingController(text: widget.searchQuery);
    _isSearching = widget.searchQuery.isNotEmpty;
    _loadUUInfo();
    _loadVersi();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUUInfo() async {
    final uuId = _currentPasal.undangUndangId;
    final kode = await QueryService.getKodeUU(uuId);
    final uu = await QueryService.getUUById(uuId);
    if (_chapterUUId != uuId) {
      final pasal = await QueryService.getPasalByUU(uuId);
      if (!mounted || _currentPasal.undangUndangId != uuId) return;
      _chapterUUId = uuId;
      _chapterPasal = pasal;
      _chapters = {};
      for (final article in pasal) {
        final chapter = article.bab?.trim();
        if (chapter != null && chapter.isNotEmpty) {
          _chapters.putIfAbsent(chapter, () => []).add(article);
        }
      }
    }
    if (mounted && _currentPasal.undangUndangId == uuId) {
      setState(() {
        _kodeUU = kode;
        _officialUrl = uu?.officialUrl;
      });
    }
  }

  Future<void> _loadVersi() async {
    final pasalId = _currentPasal.id;
    try {
      final versi = await DataService.getPasalVersi(pasalId);
      if (mounted && _currentPasal.id == pasalId) {
        setState(() => _versi = versi);
      }
    } catch (e) {
      debugPrint('Gagal memuat riwayat pasal: $e');
    }
  }

  IconData _getUUIcon(String? kode) {
    return UUColorHelper.getIcon(kode);
  }

  @override
  Widget build(BuildContext context) {
    PasalModel? prevPasal;
    PasalModel? nextPasal;

    final navigationList =
        widget.contextList?.any((p) => p.id == _currentPasal.id) == true
        ? widget.contextList!
        : _chapterPasal;
    if (navigationList.isNotEmpty) {
      final index = navigationList.indexWhere((p) => p.id == _currentPasal.id);
      if (index != -1) {
        if (index > 0) prevPasal = navigationList[index - 1];
        if (index < navigationList.length - 1) {
          nextPasal = navigationList[index + 1];
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppColors.scaffold(isDark);
    final textColor = AppColors.textPrimary(isDark);
    final uuColor = UUColorHelper.getColor(_kodeUU);

    return Scaffold(
      backgroundColor: bgColor,
      endDrawer: const SettingsDrawer(),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          tooltip: widget.onBack == null ? 'Kembali' : 'Kembali ke daftar',
          onPressed: widget.onBack ?? () => Navigator.maybePop(context),
        ),
        title: Text(
          'Baca Pasal',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          AppShowcase(
            showcaseKey: _searchKey,
            title: 'Cari di Pasal',
            description: 'Temukan kata atau frasa tertentu dalam pasal ini.\n\nKetik kata yang dicari dan teks yang cocok akan otomatis ditandai.\n\nTekan lagi untuk menutup pencarian.',
            child: IconButton(
              icon: Icon(
                _isSearching ? Icons.search_off : Icons.search,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _localSearchQuery = '';
                    _searchController.clear();
                  }
                });
              },
              tooltip: _isSearching ? 'Tutup Pencarian' : 'Cari di Pasal',
            ),
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(
                Icons.menu,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                size: 24,
              ),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              tooltip: 'Pengaturan',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.bottomNav(isDark),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
        ),
        child: SafeArea(
          child: ResponsiveContent(
            maxWidth: ResponsiveLayout.readingWidth,
            child: Row(
              children: [
                // Previous button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: prevPasal != null
                        ? () => _navigate(context, prevPasal!)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.grey[300]
                          : Colors.grey[700],
                      side: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text(
                      'Sebelumnya',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Next button
                Expanded(
                  child: FilledButton.icon(
                    onPressed: nextPasal != null
                        ? () => _navigate(context, nextPasal!)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: uuColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Text(
                      'Selanjutnya',
                      style: TextStyle(fontSize: 13),
                    ),
                    label: const Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final showChapters =
              constraints.maxWidth >= 1100 && _chapters.isNotEmpty;
          return Row(
            children: [
              SizedBox(
                width: showChapters ? 280 : 0,
                child: showChapters
                    ? _buildChapterNavigation(isDark)
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: ResponsiveContent(
                  maxWidth: ResponsiveLayout.readingWidth,
                  child: Column(
                    children: [
                      if (_isSearching)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          decoration: BoxDecoration(
                            color: bgColor,
                            border: Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          child: SizedBox(
                            height: 45,
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: TextStyle(color: textColor, fontSize: 14),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: 'Cari dalam pasal...',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[400],
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 20,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                suffixIcon: _localSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 20),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _localSearchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.inputFill(isDark),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _localSearchQuery = val;
                                });
                              },
                            ),
                          ),
                        ),

                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppColors.card(isDark),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: HighlightText(
                                                    text:
                                                        _currentPasal.nomor
                                                            .toLowerCase()
                                                            .startsWith("pasal")
                                                        ? _currentPasal.nomor
                                                        : "Pasal ${_currentPasal.nomor}",
                                                    query: _localSearchQuery,
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: -0.5,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!_currentPasal
                                                    .isVerified) ...[
                                                  const SizedBox(width: 6),
                                                  Tooltip(
                                                    triggerMode:
                                                        TooltipTriggerMode.tap,
                                                    showDuration:
                                                        const Duration(
                                                          seconds: 5,
                                                        ),
                                                    preferBelow: true,
                                                    message: 'Belum diverifikasi admin. Teks diambil dari kompilasi tidak resmi; cocokkan dengan naskah resmi sebelum dijadikan rujukan.',
                                                    child: Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      size: 20,
                                                      color: isDark
                                                          ? Colors.orange[300]
                                                          : Colors.orange[800],
                                                    ),
                                                  ),
                                                ],
                                                ValueListenableBuilder<
                                                  List<String>
                                                >(
                                                  valueListenable:
                                                      archiveService
                                                          .archivedIds,
                                                  builder: (context, ids, _) =>
                                                      ids.contains(
                                                        _currentPasal.id,
                                                      )
                                                      ? Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 6,
                                                              ),
                                                          child: Tooltip(
                                                            message:
                                                                'Tersimpan',
                                                            child: Icon(
                                                              Icons
                                                                  .bookmark_rounded,
                                                              size: 20,
                                                              color: AppColors
                                                                  .primary,
                                                            ),
                                                          ),
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                              ],
                                            ),
                                          ),

                                          AppShowcase(
                                            showcaseKey: _actionsKey,
                                            title: 'Aksi Pasal',
                                            description: 'Simpan pasal, salin isinya, cetak PDF, buka naskah resmi, dan lihat riwayat perubahan ada di sini.',
                                            child: Tooltip(
                                              message: 'Aksi pasal',
                                              child: InkWell(
                                                onTap: _showActions,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8.0,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? Colors.grey
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                        : Colors.grey
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.more_horiz_rounded,
                                                    size: 22,
                                                    color: isDark
                                                        ? Colors.grey[300]
                                                        : Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: uuColor.withValues(
                                                alpha: isDark ? 0.1 : 0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: uuColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _getUUIcon(_kodeUU),
                                                  size: 12,
                                                  color: uuColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  (_kodeUU ?? 'UU')
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: uuColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_versi.isNotEmpty &&
                                              _versi.last.status !=
                                                  PasalVersiModel.statusAsli)
                                            PasalRiwayatChip(versi: _versi),
                                        ],
                                      ),
                                      if (_currentPasal.bab != null &&
                                          _currentPasal.bab!
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _buildBabLine(isDark, uuColor),
                                      ],
                                      const SizedBox(height: 24),

                                      if (_currentPasal.judul != null &&
                                          _currentPasal.judul!
                                              .trim()
                                              .isNotEmpty) ...[
                                        Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            'JUDUL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: uuColor.withValues(
                                                alpha: 0.8,
                                              ),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        HighlightText(
                                          textAlign: TextAlign.left,
                                          text: _currentPasal.judul!,
                                          query: _localSearchQuery,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            height: 1.3,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],

                                      Container(
                                        height: 1,
                                        width: double.infinity,
                                        color: isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                      ),
                                      const SizedBox(height: 24),

                                      Row(
                                        children: [
                                          Icon(
                                            Icons.menu_book_outlined,
                                            size: 14,
                                            color: uuColor.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'ISI PASAL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: uuColor.withValues(
                                                alpha: 0.8,
                                              ),
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      LawContentFormatter(
                                        content: _currentPasal.isi,
                                        searchQuery: _localSearchQuery,
                                        fontSize: 16,
                                        height: 1.8,
                                        color: isDark
                                            ? Colors.grey[200]
                                            : const Color(0xFF333333),
                                      ),
                                    ],
                                  ),
                                ),

                                if (_versi.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  RiwayatPasalEntry(
                                    versi: _versi,
                                    onTap: () => showRiwayatPasalSheet(
                                      context,
                                      pasal: _currentPasal,
                                      kodeUU: _kodeUU ?? 'UU',
                                      versi: _versi,
                                    ),
                                  ),
                                ],

                                if (_currentPasal.penjelasan != null &&
                                    _currentPasal.penjelasan!.length > 3) ...[
                                  const SizedBox(height: 24),
                                  PenjelasanSection(
                                    penjelasan: _currentPasal.penjelasan!,
                                    searchQuery: _localSearchQuery,
                                  ),
                                ],

                                const SizedBox(height: 24),
                                RelatedPasalLinks(
                                  pasalId: _currentPasal.id,
                                  onNavigate: (pasal) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ReadPasalScreen(pasal: pasal),
                                      ),
                                    );
                                  },
                                  getUUIcon: _getUUIcon,
                                ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChapterNavigation(bool isDark) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.border(isDark))),
    ),
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Daftar bab',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        for (final chapter in _chapters.entries)
          ExpansionTile(
            key: PageStorageKey('${_chapterUUId}:${chapter.key}'),
            title: Text(chapter.key, style: const TextStyle(fontSize: 13)),
            initiallyExpanded: chapter.key == _currentPasal.bab,
            children: [
              for (final article in chapter.value)
                ListTile(
                  dense: true,
                  selected: article.id == _currentPasal.id,
                  title: Text('Pasal ${article.nomor}'),
                  onTap: () => _navigate(context, article),
                ),
            ],
          ),
      ],
    ),
  );

  void _showActions() {
    final isArchived = archiveService.archivedIds.value.contains(
      _currentPasal.id,
    );
    final naskahResmi = _naskahResmiUrl;
    showPasalActionsSheet(
      context,
      title: '${_kodeUU ?? 'UU'} Pasal ${_currentPasal.nomor}',
      actions: [
        PasalAction(
          icon: isArchived
              ? Icons.bookmark_remove_outlined
              : Icons.bookmark_add_outlined,
          label: isArchived ? 'Hapus dari Tersimpan' : 'Simpan pasal',
          description: isArchived ? null : 'Buka lagi lewat menu Tersimpan',
          color: isArchived ? null : AppColors.primary,
          onTap: _toggleArchive,
        ),
        PasalAction(
          icon: Icons.copy_rounded,
          label: 'Salin pasal',
          description: 'Sumber, nomor, judul, isi, dan penjelasan',
          onTap: _copyPasal,
        ),
        PasalAction(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Cetak atau unduh PDF',
          onTap: () => PdfExportService.exportSinglePasal(
            pasal: _currentPasal,
            searchQuery: _localSearchQuery,
          ),
        ),
        if (naskahResmi != null)
          PasalAction(
            icon: Icons.open_in_new_rounded,
            label: 'Buka naskah resmi',
            description: 'JDIH BPK, di browser',
            onTap: () => openExternalLink(context, naskahResmi),
          ),
        if (_versi.isNotEmpty)
          PasalAction(
            icon: Icons.history_rounded,
            label: 'Riwayat perubahan',
            onTap: () => showRiwayatPasalSheet(
              context,
              pasal: _currentPasal,
              kodeUU: _kodeUU ?? 'UU',
              versi: _versi,
            ),
          ),
      ],
    );
  }

  void _toggleArchive() {
    final isArchived = archiveService.archivedIds.value.contains(
      _currentPasal.id,
    );
    archiveService.toggleArchive(_currentPasal.id);
    AppNotification.show(
      context,
      isArchived ? "Dihapus dari Tersimpan" : "Berhasil Disimpan",
      color: isArchived ? Colors.grey[700] : AppColors.primary,
      icon: isArchived ? Icons.delete_outline_rounded : Icons.bookmark_rounded,
    );
  }

  /// Baris bab (breadcrumb): ketuk untuk melihat semua pasal di bab ini.
  Widget _buildBabLine(bool isDark, Color uuColor) {
    final bab = _currentPasal.bab!;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BabResultScreen(
            undangUndangId: _currentPasal.undangUndangId,
            bab: bab,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                bab,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: uuColor),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPasal() async {
    final sb = StringBuffer();
    sb.writeln(_kodeUU ?? "UU");
    sb.writeln("Pasal ${_currentPasal.nomor}");
    if (_currentPasal.judul != null && _currentPasal.judul!.trim().isNotEmpty) {
      sb.writeln(_currentPasal.judul!.toUpperCase());
    }
    sb.writeln();
    sb.writeln(_currentPasal.isi);
    if (_currentPasal.penjelasan != null &&
        _currentPasal.penjelasan!.isNotEmpty) {
      sb.writeln();
      sb.writeln("PENJELASAN");
      sb.writeln(_currentPasal.penjelasan);
    }
    if (!_currentPasal.isVerified) {
      sb.writeln();
      sb.writeln('Catatan: belum diverifikasi admin.');
    }

    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      AppNotification.show(
        context,
        "Pasal berhasil disalin",
        color: Colors.green,
        icon: Icons.copy_rounded,
      );
    }
  }

  String? get _naskahResmiUrl {
    if (_versi.isNotEmpty) {
      final v = _versi.last.naskahResmi?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    final u = _officialUrl?.trim() ?? '';
    return u.isEmpty ? null : u;
  }

  void _navigate(BuildContext context, PasalModel target) {
    setState(() {
      _currentPasal = target;
      _kodeUU = null;
      _officialUrl = null;
      _versi = [];
    });
    _loadUUInfo();
    _loadVersi();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }
}
