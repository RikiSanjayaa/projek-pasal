import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/utils/search_utils.dart';

void main() {
  group('SearchUtils', () {
    group('extractNomorQuery', () {
      test('strips "pasal " prefix (lowercase)', () {
        expect(SearchUtils.extractNomorQuery('pasal 1'), '1');
        expect(SearchUtils.extractNomorQuery('pasal 16A'), '16a');
        expect(SearchUtils.extractNomorQuery('pasal 340'), '340');
      });

      test('strips "Pasal " prefix (capitalized)', () {
        expect(SearchUtils.extractNomorQuery('Pasal 1'), '1');
        expect(SearchUtils.extractNomorQuery('PASAL 338'), '338');
      });

      test('returns query unchanged if no "pasal" prefix', () {
        expect(SearchUtils.extractNomorQuery('pidana'), 'pidana');
        expect(SearchUtils.extractNomorQuery('338'), '338');
        expect(SearchUtils.extractNomorQuery('pembunuhan'), 'pembunuhan');
      });

      test('handles empty string', () {
        expect(SearchUtils.extractNomorQuery(''), '');
      });

      test('handles whitespace trimming', () {
        expect(SearchUtils.extractNomorQuery('  pasal 1  '), '1');
        expect(SearchUtils.extractNomorQuery('pasal   16A'), '16a');
      });

      test('does not strip if "pasal" is not at start', () {
        expect(
          SearchUtils.extractNomorQuery('tentang pasal 1'),
          'tentang pasal 1',
        );
      });
    });

    group('isNomorSearch', () {
      test('returns true when query starts with digit', () {
        expect(SearchUtils.isNomorSearch('1'), isTrue);
        expect(SearchUtils.isNomorSearch('338'), isTrue);
        expect(SearchUtils.isNomorSearch('16A'), isTrue);
      });

      test('returns true when "pasal X" where X starts with digit', () {
        expect(SearchUtils.isNomorSearch('pasal 1'), isTrue);
        expect(SearchUtils.isNomorSearch('Pasal 340'), isTrue);
      });

      test('returns false for text searches', () {
        expect(SearchUtils.isNomorSearch('pidana'), isFalse);
        expect(SearchUtils.isNomorSearch('pembunuhan'), isFalse);
        expect(SearchUtils.isNomorSearch('korupsi'), isFalse);
      });

      test('returns false for empty string', () {
        expect(SearchUtils.isNomorSearch(''), isFalse);
      });
    });

    group('sortByNomorRelevance', () {
      test('returns original list if search term is empty', () {
        final items = ['10', '1', '2'];
        final result = SearchUtils.sortByNomorRelevance(
          items,
          '',
          (item) => item,
        );
        expect(result, ['10', '1', '2']);
      });

      test('exact match comes first', () {
        final items = ['10', '11', '1', '21'];
        final result = SearchUtils.sortByNomorRelevance(
          items,
          '1',
          (item) => item,
        );
        expect(result.first, '1');
      });

      test('starts-with matches come before contains matches', () {
        final items = ['21', '10', '1', '11'];
        final result = SearchUtils.sortByNomorRelevance(
          items,
          '1',
          (item) => item,
        );
        // Order: exact (1), starts-with (10, 11), contains (21)
        expect(result[0], '1'); // exact
        expect(result.sublist(1, 3).contains('10'), isTrue); // starts-with
        expect(result.sublist(1, 3).contains('11'), isTrue); // starts-with
        expect(result.last, '21'); // contains
      });

      test('within same category, sorts numerically', () {
        final items = ['12', '10', '15', '11'];
        final result = SearchUtils.sortByNomorRelevance(
          items,
          '1',
          (item) => item,
        );
        // All start with 1, so should be sorted numerically
        expect(result, ['10', '11', '12', '15']);
      });

      test('works with custom getter function', () {
        final items = [
          {'nomor': '21'},
          {'nomor': '1'},
          {'nomor': '10'},
        ];
        final result = SearchUtils.sortByNomorRelevance(
          items,
          '1',
          (item) => item['nomor']!,
        );
        expect(result[0]['nomor'], '1'); // exact match first
      });

      test('handles alphanumeric nomor like 16A', () {
        final items = ['16', '16A', '16B', '1'];
        final result = SearchUtils.sortByNomorRelevance(
          items,
          '16',
          (item) => item,
        );
        expect(result.first, '16'); // exact match
      });
    });
  });
}
