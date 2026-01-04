import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/law_content_formatter.dart';
import '../utils/uu_color_helper.dart';

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
  String? _kodeUU;
  late PasalModel _currentPasal;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPasal = widget.pasal;
    _loadUUInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUUInfo() async {
    final kode = await DataService.getKodeUU(_currentPasal.undangUndangId);
    if (mounted) {
      setState(() {
        _kodeUU = kode;
      });
    }
  }

  IconData _getUUIcon(String? kode) {
    if (kode == null) return Icons.menu_book_rounded;
    final code = kode.toUpperCase().trim();
    if (code == 'KUHP') return Icons.gavel_rounded;
    if (code.contains('KUHAP')) return Icons.policy_rounded;
    if (code.contains('ITE')) return Icons.computer_rounded;
    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return Icons.people_rounded;
    }
    return Icons.menu_book_rounded;
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
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
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

      // Simplified bottom navigation
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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

      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The Professional Card (Refined based on feedback)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.03),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.08,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Internal Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Pasal Number
                        Text(
                          _currentPasal.nomor.toLowerCase().startsWith("pasal")
                              ? _currentPasal.nomor
                              : "Pasal ${_currentPasal.nomor}",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),

                        // Right: UU Name Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: uuColor.withValues(alpha: 0.1),
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
                                size: 14,
                                color: uuColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (_kodeUU ?? 'UU').toUpperCase(),
                                style: TextStyle(
                                  color: uuColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    if (_currentPasal.judul != null) ...[
                      // "JUDUL" Label
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
                        query: widget.searchQuery,
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

                    // Full Width Divider
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 24),

                    // Section label
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

                    // 3. Body (Isi Pasal)
                    LawContentFormatter(
                      content: _currentPasal.isi,
                      searchQuery: widget.searchQuery,
                      fontSize: 16,
                      height: 1.8,
                      color: isDark
                          ? Colors.grey[200]
                          : const Color(0xFF333333),
                    ),
                  ],
                ),
              ),

              // Penjelasan section (Styled to match)
              if (_currentPasal.penjelasan != null &&
                  _currentPasal.penjelasan!.length > 3) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A202C)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 14,
                            color: Colors.blue[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PENJELASAN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      HighlightText(
                        text: _currentPasal.penjelasan!,
                        query: widget.searchQuery,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Keywords section - compact chips
              if (_currentPasal.keywords.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'KATA KUNCI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 6,
                  runSpacing: 6,
                  children: _currentPasal.keywords
                      .map(
                        (k) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            k,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],

              // Related pasal section
              if (_currentPasal.relatedIds.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: Colors.orange[400],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PASAL TERKAIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[400],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._currentPasal.relatedIds.map((relId) {
                  return FutureBuilder<PasalModel?>(
                    future: DataService.getPasalById(relId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const SizedBox.shrink();
                      }
                      final relatedPasal = snapshot.data!;

                      return FutureBuilder<String>(
                        future: DataService.getKodeUU(
                          relatedPasal.undangUndangId,
                        ),
                        builder: (context, kodeSnapshot) {
                          final kodeUU = kodeSnapshot.data ?? "UU";
                          final relColor = UUColorHelper.getColor(kodeUU);

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReadPasalScreen(pasal: relatedPasal),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: relColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getUUIcon(kodeUU),
                                      size: 16,
                                      color: relColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Pasal ${relatedPasal.nomor}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          kodeUU,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: relColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: subTextColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
              ],

              // Bottom spacing for navigation bar
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, PasalModel target) {
    // Update state directly without navigation animation
    setState(() {
      _currentPasal = target;
      _kodeUU = null; // Reset to trigger reload
    });
    _loadUUInfo();
    // Scroll to top instantly
    _scrollController.jumpTo(0);
  }
}
