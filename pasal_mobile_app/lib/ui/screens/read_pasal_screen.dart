import 'package:flutter/material.dart';
import '../../models/pasal_model.dart';
import '../../core/services/data_service.dart';
import '../utils/highlight_text.dart';

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

  // Color presets (same as library_screen)
  static const List<Color> _presetColors = [
    Color(0xFFDC2626), // Red - KUHP
    Color(0xFF2563EB), // Blue - KUHAP
    Color(0xFF059669), // Emerald - ITE
    Color(0xFFD97706), // Amber - KUHPER
    Color(0xFF7C3AED), // Violet
    Color(0xFFDB2777), // Pink
    Color(0xFF0891B2), // Cyan
    Color(0xFF4F46E5), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _loadUUInfo();
  }

  Future<void> _loadUUInfo() async {
    final kode = await DataService.getKodeUU(widget.pasal.undangUndangId);
    if (mounted) {
      setState(() {
        _kodeUU = kode;
      });
    }
  }

  Color _getUUColor(String? kode) {
    if (kode == null) return _presetColors[0];
    final code = kode.toUpperCase().trim();
    if (code.contains('KUHPER') || code.contains('PERDATA')) {
      return _presetColors[3];
    }
    if (code.contains('KUHAP')) {
      return _presetColors[1];
    }
    if (code == 'KUHP' || code.startsWith('KUHP ')) {
      return _presetColors[0];
    }
    if (code.contains('ITE')) {
      return _presetColors[2];
    }
    final hash = code.hashCode.abs();
    return _presetColors[hash % _presetColors.length];
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
        (p) => p.id == widget.pasal.id,
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
    final uuColor = _getUUColor(_kodeUU);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.pasal.nomor.toLowerCase().startsWith("pasal")
                  ? widget.pasal.nomor
                  : "Pasal ${widget.pasal.nomor}",
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (_kodeUU != null)
              Text(
                _kodeUU!,
                style: TextStyle(
                  color: uuColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        centerTitle: true,
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
                    foregroundColor: isDark ? Colors.grey[300] : Colors.grey[700],
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Pasal title/judul
                  if (widget.pasal.judul != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                      ),
                      child: HighlightText(
                        textAlign: TextAlign.center,
                        text: widget.pasal.judul!,
                        query: widget.searchQuery,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Main content - Isi Pasal
                  Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.topLeft,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section label
                        Row(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 14,
                              color: uuColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ISI PASAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: uuColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Content
                        HighlightText(
                          text: widget.pasal.isi,
                          query: widget.searchQuery,
                          textAlign: TextAlign.justify,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Penjelasan section
                  if (widget.pasal.penjelasan != null &&
                      widget.pasal.penjelasan!.length > 3) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
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
                            text: widget.pasal.penjelasan!,
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
                  if (widget.pasal.keywords.isNotEmpty) ...[
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
                      children: widget.pasal.keywords
                          .map(
                            (k) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
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
                  if (widget.pasal.relatedIds.isNotEmpty) ...[
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
                    ...widget.pasal.relatedIds.map((relId) {
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
                              final relColor = _getUUColor(kodeUU);

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
                                      color: Colors.orange.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: relColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, PasalModel target) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ReadPasalScreen(
              pasal: target,
              contextList: widget.contextList,
              searchQuery: widget.searchQuery,
            ),
        transitionDuration: Duration(seconds: 0),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
      ),
      // MaterialPageRoute(
      //   builder: (_) => ReadPasalScreen(
      //     pasal: target,
      //     contextList: widget.contextList,
      //     searchQuery: widget.searchQuery,
      //   ),
      // ),
    );
  }
}
