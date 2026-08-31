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
    'pemerkosaan': ['perkosaan', 'persetubuhan'],
    'perkosa': ['perkosaan', 'pemerkosaan', 'persetubuhan'],
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
    final expanded = expandQuery(query);
    final terms = <String>{};

    for (final term in expanded) {
      if (RegExp(r'^\d+[a-z]?$').hasMatch(term)) {
        terms.add(term);
      } else if (term.length >= 3) {
        terms.add(term);
      }
    }

    final rawTokens = normalize(query).split(' ');
    for (final token in rawTokens) {
      if (token.isNotEmpty && !_stopWords.contains(token)) {
        terms.add(token);
      }
    }

    return terms.where((t) => t.isNotEmpty).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// Extracts exact pasal number if present in the query (e.g. "pasal 362 pencurian" -> "362")
  static String extractFirstNomor(String query) {
    final normalized = normalize(query);
    final match = RegExp(
      r'(?:^|\s)(?:pasal\s+)?(\d{1,4}[a-z]?)(?:\s|$)',
    ).firstMatch(normalized);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }
    return '';
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

  /// Suggests search terms mined from the actual pasal dataset — titles,
  /// keywords, body text (isi) and penjelasan are compiled into a phrase
  /// dictionary: 1-3 word n-grams counted per pasal, with high-signal title
  /// and keyword chunks kept unconditionally. Candidates resembling [query]
  /// (exact / substring / light fuzzy typo match) are ranked by match
  /// quality, phrase commonness, then frequency. Every suggestion comes
  /// from real pasal text, so tapping it is guaranteed to return results.
  static List<String> suggestionsFromData(
    String query,
    Iterable<PasalModel> pasalList, {
    int limit = 6,
  }) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];

    final dictionary = _suggestionDictionary(pasalList);

    final scored = <({String phrase, int score, int df})>[];
    dictionary.forEach((phrase, df) {
      var best = 0;
      for (final token in tokens) {
        if (phrase == token) {
          best = 1000;
          break;
        }
        if (phrase.contains(token) || token.contains(phrase)) {
          if (best < 500) best = 500;
        } else if (_fuzzyClose(phrase, token)) {
          if (best < 300) best = 300;
        }
      }
      if (best > 0) {
        best += phrase.split(' ').length * 5; // prefer richer phrases
        scored.add((phrase: phrase, score: best, df: df));
      }
    });

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byDf = b.df.compareTo(a.df);
      if (byDf != 0) return byDf;
      return a.phrase.compareTo(b.phrase);
    });

    return scored.take(limit).map((e) => e.phrase).toList();
  }

  static Map<String, int>? _phraseDfCache;
  static int _phraseDfCacheLen = -1;

  /// ponytail: dictionary cache is keyed by dataset length only — a sync
  /// that keeps the same pasal count won't invalidate it; add force/epoch
  /// param wired to the sync hook if staleness ever shows up.
  static Map<String, int> _suggestionDictionary(
    Iterable<PasalModel> pasalList, {
    bool force = false,
  }) {
    final list = pasalList.toList();
    if (!force && _phraseDfCache != null && _phraseDfCacheLen == list.length) {
      return _phraseDfCache!;
    }

    final df = <String, int>{};
    void record(Set<String> seen, String phrase) {
      final p = normalize(phrase);
      if (p.isEmpty || p.length < 4) return;
      if (seen.add(p)) df[p] = (df[p] ?? 0) + 1;
    }

    for (final pasal in list) {
      final seen = <String>{}; // per-pasal dedupe → document frequency

      // High-signal fields: title chunks and keywords, any length.
      final title = pasal.judul ?? '';
      if (title.trim().isNotEmpty) {
        for (final chunk in title.split(RegExp(r'[,;()\[\]\-–—]'))) {
          final words = tokenize(chunk);
          if (words.isNotEmpty && words.length <= 6) record(seen, chunk);
        }
      }
      for (final keyword in pasal.keywords) {
        record(seen, keyword);
      }

      // Body text (isi + penjelasan): 1-3 word n-gram windows.
      final bodyTokens = tokenize(
        [title, pasal.isi, pasal.penjelasan ?? ''].join(' '),
      );
      for (var i = 0; i < bodyTokens.length; i++) {
        record(seen, bodyTokens[i]);
        if (i + 1 < bodyTokens.length) {
          record(seen, '${bodyTokens[i]} ${bodyTokens[i + 1]}');
        }
        if (i + 2 < bodyTokens.length) {
          record(
            seen,
            '${bodyTokens[i]} ${bodyTokens[i + 1]} ${bodyTokens[i + 2]}',
          );
        }
      }
    }

    // Prune: drop noisy unigrams (seen in only one pasal); keep phrases.
    // Cap by document frequency so the dictionary stays bounded.
    final kept = df.entries.where((e) {
      final wordCount = e.key.split(' ').length;
      return wordCount == 1 ? e.value >= 2 : true;
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final result = <String, int>{
      for (final e in kept.take(30000)) e.key: e.value,
    };

    _phraseDfCache = result;
    _phraseDfCacheLen = list.length;
    return result;
  }

  /// Light typo tolerance: distance ≤1 for short words, ≤2 for long ones.
  static bool _fuzzyClose(String a, String b) {
    if (a.length < 4 || b.length < 4) return false;
    final maxDist = (a.length >= 7 && b.length >= 7) ? 2 : 1;
    return _levenshteinDistance(a, b, maxDist) <= maxDist;
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

  static int scorePasal(PasalModel pasal, String query) =>
      _scoreWithMatches(pasal, query).score;

  static ({int score, int matchedTokens}) _scoreWithMatches(
    PasalModel pasal,
    String query,
  ) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return (score: 0, matchedTokens: 0);

    final nomorQuery = extractNomorQuery(normalizedQuery);
    final firstNomor = extractFirstNomor(normalizedQuery);
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
    var matchedTokens = 0;

    if (nomorQuery.isNotEmpty) {
      if (nomor == nomorQuery) score += 1000;
      if ('pasal $nomor' == normalizedQuery) score += 1000;
      if (nomor.startsWith(nomorQuery)) {
        final lengthGap = (nomor.length - nomorQuery.length).abs();
        score += (260 - (lengthGap * 45)).clamp(60, 260);
      }
      if (nomor.contains(nomorQuery)) score += 80;
    }

    if (firstNomor.isNotEmpty && firstNomor != nomorQuery) {
      if (nomor == firstNomor) score += 950;
      else if (nomor.startsWith(firstNomor)) score += 180;
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

    // Full phrase match in content strongly outranks scattered token hits.
    if (content.contains(normalizedQuery)) score += 150;

    for (final term in expandedTerms) {
      if (term.length <= 1) continue;
      if (title.contains(term)) score += 75;
      if (keywords.any((keyword) => keyword.contains(term))) score += 65;
      if (content.contains(term)) score += 35;
      if (explanation.contains(term)) score += 20;
      if (searchable.contains(term)) tokenMatches++;
    }

    if (tokens.isNotEmpty) {
      for (final token in tokens) {
        if (searchable.contains(token)) matchedTokens++;
      }
    }

    if (tokens.isNotEmpty && tokenMatches == 0) return (score: 0, matchedTokens: 0);
    if (tokens.length > 1 && tokenMatches >= tokens.length) score += 90;
    if (tokens.length > 1 && tokenMatches == 1) score -= 20;

    return (score: score, matchedTokens: matchedTokens);
  }

  static List<PasalModel> rankPasal(
    Iterable<PasalModel> pasalList,
    String query,
  ) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return pasalList.toList();

    final list = pasalList.toList();
    final nomorQuery = extractNomorQuery(normalizedQuery);
    if (_isSpecificNomorSearch(normalizedQuery, nomorQuery)) {
      final exactMatches = list
          .where((pasal) => normalize(pasal.nomor) == nomorQuery)
          .toList();

      if (exactMatches.isNotEmpty) {
        exactMatches.sort(
          (a, b) =>
              _nomorSortValue(a.nomor).compareTo(_nomorSortValue(b.nomor)),
        );
        return exactMatches;
      }
    }

    final tokens = tokenize(normalizedQuery);
    final scored = <({PasalModel pasal, int score, int matchedTokens})>[];
    for (final pasal in list) {
      final (:score, :matchedTokens) = _scoreWithMatches(pasal, normalizedQuery);
      if (score > 0) scored.add((pasal: pasal, score: score, matchedTokens: matchedTokens));
    }

    // Multi-word query: if enough pasal match EVERY token, drop the ones
    // matching only some tokens — more words should narrow, not widen.
    if (tokens.isNotEmpty &&
        tokens.length > 1 &&
        scored.length > 4) {
      final fullMatches = scored
          .where((item) => item.matchedTokens == tokens.length)
          .toList();
      if (fullMatches.length >= 5) {
        scored.removeWhere((item) => item.matchedTokens < tokens.length);
      }
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

  static const Set<String> _validLegalTerms = {
    'pencurian',
    'pencarian',
    'penyidik',
    'penyelidik',
    'penuntutan',
    'pengadilan',
    'penganiayaan',
    'pembunuhan',
    'penipuan',
    'penggelapan',
    'pemalsuan',
    'perjudian',
    'narkotika',
    'psikotropika',
  };

  /// Suggests a typo correction (e.g. "penyudik" -> "penyidik")
  static String? suggestTypoCorrection(String query) {
    final normalized = normalize(query);
    if (normalized.isEmpty || _validLegalTerms.contains(normalized)) return null;

    final tokens = tokenize(normalized);
    for (final token in tokens) {
      if (_validLegalTerms.contains(token)) continue;
      for (final validTerm in _validLegalTerms) {
        if ((token.length - validTerm.length).abs() <= 1) {
          if (_levenshteinDistance(token, validTerm, 1) <= 1) {
            return normalized.replaceAll(token, validTerm);
          }
        }
      }
    }
    return null;
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

  static bool _isSpecificNomorSearch(
    String normalizedQuery,
    String nomorQuery,
  ) {
    if (nomorQuery.isEmpty) return false;
    final pattern = RegExp(r'^\d{1,4}[a-z]?(?:\s+(?:bis|ter))?$');
    if (!pattern.hasMatch(nomorQuery)) return false;

    return normalizedQuery == nomorQuery ||
        normalizedQuery == 'pasal $nomorQuery';
  }

  /// Extracts a context-aware snippet from [pasal.isi] or [pasal.penjelasan]
  /// ensuring that matches in long articles are visible in search results.
  static SearchSnippet extractSnippet({
    required PasalModel pasal,
    required String query,
    int leadingChars = 40,
    int totalChars = 160,
  }) {
    final cleanQuery = query.trim();
    final defaultIsiText = pasal.isi.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanQuery.isEmpty || isNomorSearch(cleanQuery)) {
      return SearchSnippet(
        text: defaultIsiText,
        source: SnippetSource.defaultIsi,
        hasMatch: false,
      );
    }

    final terms = highlightTerms(cleanQuery);
    if (terms.isEmpty) {
      return SearchSnippet(
        text: defaultIsiText,
        source: SnippetSource.defaultIsi,
        hasMatch: false,
      );
    }

    final isiMatch = _findSnippetMatch(
      rawText: pasal.isi,
      terms: terms,
      cleanQuery: cleanQuery,
      source: SnippetSource.isi,
      leadingChars: leadingChars,
      totalChars: totalChars,
    );

    final penjelasanMatch =
        (pasal.penjelasan != null && pasal.penjelasan!.trim().isNotEmpty)
            ? _findSnippetMatch(
              rawText: pasal.penjelasan!,
              terms: terms,
              cleanQuery: cleanQuery,
              source: SnippetSource.penjelasan,
              leadingChars: leadingChars,
              totalChars: totalChars,
            )
            : null;

    if (isiMatch == null && penjelasanMatch == null) {
      return SearchSnippet(
        text: defaultIsiText,
        source: SnippetSource.defaultIsi,
        hasMatch: false,
      );
    }

    if (isiMatch != null && penjelasanMatch == null) {
      return isiMatch.snippet;
    }

    if (isiMatch == null && penjelasanMatch != null) {
      return penjelasanMatch.snippet;
    }

    // Both matched: compare match quality
    // 1. If one matched full clean query, prefer it
    if (penjelasanMatch!.isFullQueryMatch && !isiMatch!.isFullQueryMatch) {
      return penjelasanMatch.snippet;
    }
    if (isiMatch!.isFullQueryMatch && !penjelasanMatch.isFullQueryMatch) {
      return isiMatch.snippet;
    }

    // 2. If one matched a strictly longer term, prefer it
    if (penjelasanMatch.matchedTermLength > isiMatch.matchedTermLength) {
      return penjelasanMatch.snippet;
    }

    // 3. Default prefer isi
    return isiMatch.snippet;
  }

  static ({
    SearchSnippet snippet,
    int matchedTermLength,
    bool isFullQueryMatch,
  })?
  _findSnippetMatch({
    required String rawText,
    required List<String> terms,
    required String cleanQuery,
    required SnippetSource source,
    required int leadingChars,
    required int totalChars,
  }) {
    final cleanText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanText.isEmpty) return null;

    final lowerText = cleanText.toLowerCase();
    final lowerCleanQuery = cleanQuery.toLowerCase();
    int bestIndex = -1;
    String bestTerm = '';

    for (final term in terms) {
      final index = lowerText.indexOf(term.toLowerCase());
      if (index == -1) continue;
      if (bestIndex == -1 ||
          term.length > bestTerm.length ||
          (term.length == bestTerm.length && index < bestIndex)) {
        bestIndex = index;
        bestTerm = term;
      }
    }

    if (bestIndex == -1) return null;

    final isFullQuery =
        lowerCleanQuery.isNotEmpty && lowerText.contains(lowerCleanQuery);

    final snippetText = _buildWindowSnippet(
      cleanText: cleanText,
      matchIndex: bestIndex,
      matchLength: bestTerm.length,
      leadingChars: leadingChars,
      totalChars: totalChars,
    );

    return (
      snippet: SearchSnippet(
        text: snippetText,
        source: source,
        hasMatch: true,
      ),
      matchedTermLength: bestTerm.length,
      isFullQueryMatch: isFullQuery,
    );
  }

  static String _buildWindowSnippet({
    required String cleanText,
    required int matchIndex,
    required int matchLength,
    required int leadingChars,
    required int totalChars,
  }) {
    if (cleanText.length <= totalChars) {
      return cleanText;
    }

    // If match is near the beginning
    if (matchIndex <= leadingChars + 10) {
      var end = totalChars.clamp(0, cleanText.length);
      if (end < cleanText.length) {
        final spaceIndex = cleanText.indexOf(' ', end);
        if (spaceIndex != -1 && spaceIndex - end <= 25) {
          end = spaceIndex;
        }
        return '${cleanText.substring(0, end).trim()}...';
      }
      return cleanText;
    }

    // Match is in middle or end of long text
    var start = (matchIndex - leadingChars).clamp(0, cleanText.length);
    final spaceBefore = cleanText.indexOf(' ', start);
    if (spaceBefore != -1 && spaceBefore < matchIndex) {
      start = spaceBefore + 1;
    }

    var end = (start + totalChars).clamp(0, cleanText.length);
    if (end < cleanText.length) {
      final spaceAfter = cleanText.indexOf(' ', end);
      if (spaceAfter != -1 && spaceAfter - end <= 25) {
        end = spaceAfter;
      }
      return '... ${cleanText.substring(start, end).trim()}...';
    } else {
      return '... ${cleanText.substring(start).trim()}';
    }
  }
}

enum SnippetSource { isi, penjelasan, defaultIsi }

class SearchSnippet {
  final String text;
  final SnippetSource source;
  final bool hasMatch;

  const SearchSnippet({
    required this.text,
    required this.source,
    this.hasMatch = false,
  });

  bool get isFromPenjelasan => source == SnippetSource.penjelasan;
}

