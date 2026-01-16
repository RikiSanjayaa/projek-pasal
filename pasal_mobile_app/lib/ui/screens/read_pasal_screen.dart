import 'package:flutter/material.dart';
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
import '../widgets/app_showcase.dart';

class ReadPasalScreen extends StatefulWidget {
  final PasalModel pasal;
  final String searchQuery;
  final List<PasalModel>? contextList;

  const ReadPasalScreen({
    super.key,
    required this.pasal,
    this.searchQuery = '',
    this.contextList,
  });

  @override
  State<ReadPasalScreen> createState() => _ReadPasalScreenState();
}

class _ReadPasalScreenState extends State<ReadPasalScreen> {
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _archiveKey = GlobalKey();
  final GlobalKey _copyKey = GlobalKey();
  String? _kodeUU;
  late PasalModel _currentPasal;
  final ScrollController _scrollController = ScrollController();

  bool _isSearching = false;
  late TextEditingController _searchController;
  late String _localSearchQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      bool hasShown = prefs.getBool('has_shown_read_pasal_showcase') ?? false;

      if (!hasShown && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ShowCaseWidget.of(
              context,
            ).startShowCase([_searchKey, _archiveKey, _copyKey]);
            prefs.setBool('has_shown_read_pasal_showcase', true);
          }
        });
      }
    });
    _currentPasal = widget.pasal;
    _localSearchQuery = widget.searchQuery;
    _searchController = TextEditingController(text: widget.searchQuery);
    _isSearching = widget.searchQuery.isNotEmpty;
    _loadUUInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUUInfo() async {
    final kode = await QueryService.getKodeUU(_currentPasal.undangUndangId);
    if (mounted) {
      setState(() {
        _kodeUU = kode;
      });
    }
  }

  IconData _getUUIcon(String? kode) {
    return UUColorHelper.getIcon(kode);
  }

  @override
  Widget build(BuildContext context) {
    PasalModel? prevPasal;
    PasalModel? nextPasal;

    if (widget.contextList != null && widget.contextList!.isNotEmpty) {
      final index = widget.contextList!.indexWhere(
        (p) => p.id == _currentPasal.id,
      );
      if (index != -1) {
        if (index > 0) prevPasal = widget.contextList![index - 1];
        if (index < widget.contextList!.length - 1) {
          nextPasal = widget.contextList![index + 1];
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
          onPressed: () => Navigator.pop(context),
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
            title: 'Cari Teks',
            description: 'Cari kata tertentu di dalam pasal ini.',
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
            builder:
                (ctx) => IconButton(
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
          child: Row(
            children: [
              // Previous button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      prevPasal != null
                          ? () => _navigate(context, prevPasal!)
                          : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.grey[300] : Colors.grey[700],
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
                  onPressed:
                      nextPasal != null
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

      body: Column(
        children: [
          if (_isSearching)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark
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
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    suffixIcon:
                        _localSearchQuery.isNotEmpty
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
                          color:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _currentPasal.nomor
                                                .toLowerCase()
                                                .startsWith("pasal")
                                            ? _currentPasal.nomor
                                            : "Pasal ${_currentPasal.nomor}",
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: uuColor.withValues(
                                          alpha: isDark ? 0.1 : 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: uuColor.withValues(alpha: 0.2),
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
                                            (_kodeUU ?? 'UU').toUpperCase(),
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
                                  ],
                                ),
                              ),

                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Archive Button
                                  AppShowcase(
                                    showcaseKey: _archiveKey,
                                    title: 'Simpan',
                                    description:
                                        'Simpan pasal ke halaman Favorit.',
                                    child: ValueListenableBuilder<List<String>>(
                                      valueListenable:
                                          archiveService.archivedIds,
                                      builder: (context, ids, _) {
                                        final isArchived = ids.contains(
                                          _currentPasal.id,
                                        );
                                        return InkWell(
                                          onTap: () {
                                            archiveService.toggleArchive(
                                              _currentPasal.id,
                                            );

                                            AppNotification.show(
                                              context,
                                              isArchived
                                                  ? "Dihapus dari Tersimpan"
                                                  : "Berhasil Disimpan",
                                              color:
                                                  isArchived
                                                      ? Colors.grey[700]
                                                      : AppColors.primary,
                                              icon:
                                                  isArchived
                                                      ? Icons
                                                          .delete_outline_rounded
                                                      : Icons.bookmark_rounded,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? Colors.grey.withValues(
                                                        alpha: 0.1,
                                                      )
                                                      : Colors.grey.withValues(
                                                        alpha: 0.05,
                                                      ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              isArchived
                                                  ? Icons.bookmark_rounded
                                                  : Icons
                                                      .bookmark_border_rounded,
                                              size: 18,
                                              color:
                                                  isArchived
                                                      ? AppColors.primary
                                                      : (isDark
                                                          ? Colors.grey[400]
                                                          : Colors.grey[600]),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Copy Button
                                  AppShowcase(
                                    showcaseKey: _copyKey,
                                    title: 'Salin',
                                    description:
                                        'Salin isi pasal lengkap ke clipboard.',
                                    child: InkWell(
                                      onTap: () async {
                                        final sb = StringBuffer();
                                        sb.writeln(_kodeUU ?? "UU");
                                        sb.writeln(
                                          "Pasal ${_currentPasal.nomor}",
                                        );
                                        if (_currentPasal.judul != null &&
                                            _currentPasal.judul!
                                                .trim()
                                                .isNotEmpty) {
                                          sb.writeln(
                                            _currentPasal.judul!.toUpperCase(),
                                          );
                                        }
                                        sb.writeln();
                                        sb.writeln(_currentPasal.isi);
                                        if (_currentPasal.penjelasan != null &&
                                            _currentPasal
                                                .penjelasan!
                                                .isNotEmpty) {
                                          sb.writeln();
                                          sb.writeln("PENJELASAN");
                                          sb.writeln(_currentPasal.penjelasan);
                                        }

                                        await Clipboard.setData(
                                          ClipboardData(text: sb.toString()),
                                        );
                                        if (context.mounted) {
                                          AppNotification.show(
                                            context,
                                            "Pasal berhasil disalin",
                                            color: Colors.green,
                                            icon: Icons.copy_rounded,
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                          color:
                                              isDark
                                                  ? Colors.grey.withValues(
                                                    alpha: 0.1,
                                                  )
                                                  : Colors.grey.withValues(
                                                    alpha: 0.05,
                                                  ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                          color:
                                              isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          if (_currentPasal.judul != null &&
                              _currentPasal.judul!.trim().isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'JUDUL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: uuColor.withValues(alpha: 0.8),
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
                            color:
                                isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.1),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 14,
                                color: uuColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ISI PASAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: uuColor.withValues(alpha: 0.8),
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
                            color:
                                isDark
                                    ? Colors.grey[200]
                                    : const Color(0xFF333333),
                          ),
                        ],
                      ),
                    ),

                    if (_currentPasal.penjelasan != null &&
                        _currentPasal.penjelasan!.length > 3) ...[
                      const SizedBox(height: 24),
                      PenjelasanSection(
                        penjelasan: _currentPasal.penjelasan!,
                        searchQuery: _localSearchQuery,
                      ),
                    ],

                    if (_currentPasal.keywords.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      KeywordsSection(keywords: _currentPasal.keywords),
                    ],

                    const SizedBox(height: 24),
                    RelatedPasalLinks(
                      pasalId: _currentPasal.id,
                      onNavigate: (pasal) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReadPasalScreen(pasal: pasal),
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
    );
  }

  void _navigate(BuildContext context, PasalModel target) {
    setState(() {
      _currentPasal = target;
      _kodeUU = null;
    });
    _loadUUInfo();
    _scrollController.jumpTo(0);
  }
}
