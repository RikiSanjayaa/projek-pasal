import '../../models/pasal_model.dart';

/// Utility class for search-related operations
///
/// Provides shared search functionality for both HomeScreen filtering
/// and other search contexts in the app.
class SearchUtils {
  static const Set<String> _stopWords = {
    'dan',
    'atau',
    'yang',
    'di',
    'ke',
    'dari',
    'dengan',
    'untuk',
    'pada',
    'dalam',
    'itu',
    'ini',
    'adalah',
    'tentang',
    'karena',
    'sebagai',
    'secara',
    'atas',
    'oleh',
    'pasal',
  };

  static const Map<String, List<String>> _synonyms = {
    'maling': ['pencurian', 'mencuri', 'mengambil barang'],
    'curi': ['pencurian', 'mencuri', 'mengambil barang'],
    'nyuri': ['pencurian', 'mencuri', 'mengambil barang'],
    'barang curian': ['penadahan', 'hasil kejahatan'],
    'penadah': ['penadahan', 'hasil kejahatan'],
    'tipu': ['penipuan', 'perbuatan curang'],
    'bohong': ['penipuan', 'keterangan palsu'],
    'ancam': ['pengancaman', 'ancaman kekerasan'],
    'aniaya': ['penganiayaan', 'kekerasan'],
    'bunuh': ['pembunuhan', 'menghilangkan nyawa'],
    'narkoba': ['narkotika', 'psikotropika'],
    'sabu': ['narkotika', 'psikotropika'],
    'ganja': ['narkotika'],
    'judi': ['perjudian'],
    'judi online': ['perjudian', 'transaksi elektronik'],
    'korupsi': ['tindak pidana korupsi', 'merugikan keuangan negara'],
    'suap': ['gratifikasi', 'korupsi'],
    'fitnah': ['pencemaran nama baik', 'penghinaan'],
    'hoax': ['berita bohong', 'kabar bohong'],
    'palsu': ['pemalsuan', 'surat palsu', 'keterangan palsu'],
    'gelap': ['penggelapan'],
    'rampas': ['perampasan', 'kekerasan'],
    'paksa': ['pemaksaan', 'kekerasan'],
    'rusak': ['perusakan', 'merusak'],
  };

  /// Strips "pasal" prefix from search query
  ///
  /// Examples:
  /// - "pasal 1" → "1"
  /// - "pasal 16A" → "16A"
  /// - "pidana" → "pidana" (unchanged)
  static String extractNomorQuery(String query) {
    final q = normalize(query);
    if (q.startsWith('pasal ')) {
      return q.substring(6).trim();
    }
    return q;
  }

  /// Normalizes Indonesian legal text/search input.
  ///
  /// This intentionally handles common OCR/typing noise without changing the
  /// source data: punctuation, repeated whitespace, and frequent OCR digit
  /// substitutions.
  static String normalize(String value) {
    var text = value.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    text = text
        .replaceAll(RegExp(r'[|•·“”"‘’`´]'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  static List<String> tokenize(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return [];
    return normalized
        .split(' ')
        .where((token) => token.length > 1 && !_stopWords.contains(token))
        .toList();
  }

  static List<String> expandQuery(String query) {
    final normalized = normalize(query);
    final terms = <String>{};

    if (normalized.isNotEmpty) terms.add(normalized);
    for (final token in tokenize(normalized)) {
      terms.add(token);
      for (final synonym in _synonyms[token] ?? const <String>[]) {
        terms.add(normalize(synonym));
      }
    }

    _synonyms.forEach((phrase, synonyms) {
      if (normalized.contains(phrase)) {
        for (final synonym in synonyms) {
          terms.add(normalize(synonym));
        }
      }
    });

    return terms.where((term) => term.isNotEmpty).toList();
  }

  static List<String> highlightTerms(String query) {
    return expandQuery(query).where((term) => term.length >= 3).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  static List<String> suggestionsForQuery(String query) {
    final normalized = normalize(query);
    if (normalized.isEmpty) return [];

    final suggestions = <String>{};
    _synonyms.forEach((term, aliases) {
      if (normalized.contains(term) || term.contains(normalized)) {
        suggestions.addAll(aliases);
      }
    });

    return suggestions.take(6).toList();
  }

  static String searchableTextForPasal(PasalModel pasal) {
    return normalize(
      [
        pasal.nomor,
        pasal.judul ?? '',
        pasal.isi,
        pasal.penjelasan ?? '',
        pasal.keywords.join(' '),
      ].join(' '),
    );
  }

  static int scorePasal(PasalModel pasal, String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return 0;

    final nomorQuery = extractNomorQuery(normalizedQuery);
    final nomor = normalize(pasal.nomor);
    final title = normalize(pasal.judul ?? '');
    final content = normalize(pasal.isi);
    final explanation = normalize(pasal.penjelasan ?? '');
    final keywords = pasal.keywords.map(normalize).toList();
    final searchable = [
      nomor,
      title,
      content,
      explanation,
      ...keywords,
    ].join(' ');

    var score = 0;

    if (nomorQuery.isNotEmpty) {
      if (nomor == nomorQuery) score += 1000;
      if ('pasal $nomor' == normalizedQuery) score += 1000;
      if (nomor.startsWith(nomorQuery)) score += 450;
      if (nomor.contains(nomorQuery)) score += 180;
    }

    if (title.contains(normalizedQuery)) score += 320;
    if (keywords.any((keyword) => keyword == normalizedQuery)) score += 280;
    if (keywords.any((keyword) => keyword.contains(normalizedQuery))) {
      score += 180;
    }
    if (content.contains(normalizedQuery)) score += 120;
    if (explanation.contains(normalizedQuery)) score += 70;

    final expandedTerms = expandQuery(normalizedQuery);
    final tokens = tokenize(normalizedQuery);
    var tokenMatches = 0;

    for (final term in expandedTerms) {
      if (term.length <= 1) continue;
      if (title.contains(term)) score += 75;
      if (keywords.any((keyword) => keyword.contains(term))) score += 65;
      if (content.contains(term)) score += 35;
      if (explanation.contains(term)) score += 20;
      if (searchable.contains(term)) tokenMatches++;
    }

    for (final token in tokens) {
      if (_hasFuzzyTokenMatch(token, searchable)) {
        score += 18;
        tokenMatches++;
      }
    }

    if (tokens.isNotEmpty && tokenMatches == 0) return 0;
    if (tokens.length > 1 && tokenMatches >= tokens.length) score += 90;
    if (tokens.length > 1 && tokenMatches == 1) score -= 20;

    return score;
  }

  static List<PasalModel> rankPasal(
    Iterable<PasalModel> pasalList,
    String query,
  ) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return pasalList.toList();

    final scored = <({PasalModel pasal, int score})>[];
    for (final pasal in pasalList) {
      final score = scorePasal(pasal, normalizedQuery);
      if (score > 0) scored.add((pasal: pasal, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return _nomorSortValue(
        a.pasal.nomor,
      ).compareTo(_nomorSortValue(b.pasal.nomor));
    });

    return scored.map((item) => item.pasal).toList();
  }

  static bool _hasFuzzyTokenMatch(String token, String text) {
    if (token.length < 4) return false;
    final words = text.split(' ');
    final maxDistance = token.length <= 5 ? 1 : 2;
    for (final word in words) {
      if ((word.length - token.length).abs() > maxDistance) continue;
      if (_levenshteinDistance(token, word, maxDistance) <= maxDistance) {
        return true;
      }
    }
    return false;
  }

  static int _levenshteinDistance(String a, String b, int maxDistance) {
    if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      var rowMin = current[0];
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = [
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        ].reduce((value, element) => value < element ? value : element);
        if (current[j + 1] < rowMin) rowMin = current[j + 1];
      }
      if (rowMin > maxDistance) return maxDistance + 1;
      previous = current;
    }
    return previous[b.length];
  }

  static int _nomorSortValue(String nomor) {
    return int.tryParse(normalize(nomor).replaceAll(RegExp(r'[^0-9]'), '')) ??
        999999;
  }

  /// Sorts a list of items by numeric relevance for a search term.
  ///
  /// Priority order:
  /// 1. Exact match (e.g., "1" matches "1")
  /// 2. Starts with (e.g., "1" matches "10", "11", "12")
  /// 3. Contains (e.g., "1" matches "21", "31", "161")
  ///
  /// Within each category, items are sorted numerically.
  static List<T> sortByNomorRelevance<T>(
    List<T> items,
    String searchTerm,
    String Function(T) getNomor,
  ) {
    if (searchTerm.isEmpty) return items;

    final term = normalize(searchTerm);
    return List.from(items)..sort((a, b) {
      final aNomor = getNomor(a).toLowerCase();
      final bNomor = getNomor(b).toLowerCase();

      // Exact match gets highest priority
      final aExact = aNomor == term;
      final bExact = bNomor == term;
      if (aExact != bExact) return aExact ? -1 : 1;

      // Starts with gets second priority
      final aStarts = aNomor.startsWith(term);
      final bStarts = bNomor.startsWith(term);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      // Within same category, sort numerically
      final aNum =
          int.tryParse(aNomor.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      final bNum =
          int.tryParse(bNomor.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      return aNum.compareTo(bNum);
    });
  }

  /// Checks if the search term looks like a pasal number search
  /// (starts with a digit)
  static bool isNomorSearch(String query) {
    final q = extractNomorQuery(query);
    return q.isNotEmpty && RegExp(r'^\d').hasMatch(q);
  }
}
