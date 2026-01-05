/// Utility class for search-related operations
///
/// Provides shared search functionality for both HomeScreen filtering
/// and other search contexts in the app.
class SearchUtils {
  /// Strips "pasal" prefix from search query
  ///
  /// Examples:
  /// - "pasal 1" → "1"
  /// - "pasal 16A" → "16A"
  /// - "pidana" → "pidana" (unchanged)
  static String extractNomorQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.startsWith('pasal ')) {
      return q.substring(6).trim();
    }
    return q;
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

    final term = searchTerm.toLowerCase();
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
