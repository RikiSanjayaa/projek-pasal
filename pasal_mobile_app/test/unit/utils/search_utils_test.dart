import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/core/utils/search_utils.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';

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

    group('rankPasal', () {
      final pasalList = [
        PasalModel(
          id: '1',
          undangUndangId: 'uu-1',
          nomor: '480',
          judul: 'Penadahan',
          isi:
              'Barangsiapa membeli atau menyimpan barang yang diperoleh dari kejahatan.',
          keywords: const ['penadahan', 'hasil kejahatan'],
        ),
        PasalModel(
          id: '2',
          undangUndangId: 'uu-1',
          nomor: '362',
          judul: 'Pencurian',
          isi:
              'Barangsiapa mengambil barang sesuatu yang seluruhnya atau sebagian kepunyaan orang lain.',
          keywords: const ['pencurian'],
        ),
        PasalModel(
          id: '3',
          undangUndangId: 'uu-1',
          nomor: '340',
          judul: 'Pembunuhan berencana',
          isi:
              'Barangsiapa dengan sengaja dan dengan rencana terlebih dahulu merampas nyawa orang lain.',
          keywords: const ['pembunuhan'],
        ),
      ];

      test('prioritizes exact pasal number', () {
        final result = SearchUtils.rankPasal(pasalList, 'pasal 480');
        expect(result.first.nomor, '480');
      });

      test(
        'specific pasal number search returns exact number when available',
        () {
          final result = SearchUtils.rankPasal([
            PasalModel(
              id: '12',
              undangUndangId: 'uu-1',
              nomor: '12',
              isi: 'Isi pasal dua belas.',
              keywords: const [],
            ),
            PasalModel(
              id: '120',
              undangUndangId: 'uu-1',
              nomor: '120',
              isi: 'Isi pasal seratus dua puluh.',
              keywords: const [],
            ),
            PasalModel(
              id: '128',
              undangUndangId: 'uu-1',
              nomor: '128',
              isi: 'Isi pasal seratus dua puluh delapan.',
              keywords: const [],
            ),
          ], 'pasal 12');

          expect(result.map((pasal) => pasal.nomor), ['12']);
        },
      );

      test(
        'specific pasal number search falls back to nearby numbers when exact is unavailable',
        () {
          final result = SearchUtils.rankPasal([
            PasalModel(
              id: '120',
              undangUndangId: 'uu-1',
              nomor: '120',
              isi: 'Isi pasal seratus dua puluh.',
              keywords: const [],
            ),
            PasalModel(
              id: '128',
              undangUndangId: 'uu-1',
              nomor: '128',
              isi: 'Isi pasal seratus dua puluh delapan.',
              keywords: const [],
            ),
          ], 'pasal 12');

          expect(result.map((pasal) => pasal.nomor), ['120', '128']);
        },
      );

      test('expands simple legal synonyms', () {
        final result = SearchUtils.rankPasal(pasalList, 'maling');
        expect(result.first.nomor, '362');
      });

      test('handles light typo with fuzzy token matching', () {
        final result = SearchUtils.rankPasal(pasalList, 'penadahn');
        expect(result.first.nomor, '480');
      });

      test('returns empty list when nothing is relevant', () {
        final result = SearchUtils.rankPasal(pasalList, 'meteorologi');
        expect(result, isEmpty);
      });
    });

    group('smart suggestions', () {
      test('returns legal suggestions for everyday words', () {
        final suggestions = SearchUtils.suggestionsForQuery('maling');
        expect(suggestions, contains('pencurian'));
        expect(suggestions, contains('mengambil barang'));
      });

      test('returns highlight terms with expanded aliases', () {
        final terms = SearchUtils.highlightTerms('tipu');
        expect(terms, contains('tipu'));
        expect(terms, contains('penipuan'));
        expect(terms, contains('perbuatan curang'));
      });

      test('includes pasal numbers and single-word titles in highlight terms', () {
        final terms = SearchUtils.highlightTerms('pasal 362 pencurian');
        expect(terms, contains('362'));
        expect(terms, contains('pencurian'));
        expect(terms, contains('mencuri'));
      });

      test('includes 1-digit or 2-digit pasal numbers in highlight terms', () {
        final terms = SearchUtils.highlightTerms('pasal 1');
        expect(terms, contains('1'));

        final terms12 = SearchUtils.highlightTerms('12');
        expect(terms12, contains('12'));
      });
    });

    group('extractSnippet', () {
      final pasalPanjang = PasalModel(
        id: 'p-long',
        undangUndangId: 'uu-1',
        nomor: '450',
        judul: 'Pasal Panjang Multi Ayat',
        isi:
            '(1) Setiap orang yang melakukan perbuatan persiapan pidana dipidana dengan sepertiga hukuman pokok. '
            '(2) Penjatuhan pidana denda dapat dialihkan menjadi pidana kerja sosial. '
            '(3) Tindak pidana yang dilakukan dengan kekerasan berat dapat dijatuhi pidana penjara seumur hidup atau pidana mati. '
            '(4) Ketentuan lebih lanjut diatur dalam Peraturan Pemerintah.',
        penjelasan:
            'Yang dimaksud dengan kekerasan berat dalam pasal ini adalah perbuatan yang mengakibatkan luka berat atau kematian secara langsung.',
        keywords: const ['kekerasan', 'pidana mati'],
      );

      test('returns beginning of text when match is at the start', () {
        final snippet = SearchUtils.extractSnippet(
          pasal: pasalPanjang,
          query: 'persiapan pidana',
        );

        expect(snippet.hasMatch, isTrue);
        expect(snippet.isFromPenjelasan, isFalse);
        expect(snippet.text.startsWith('...'), isFalse);
        expect(snippet.text, contains('persiapan pidana'));
      });

      test(
        'extracts middle context with leading and trailing ellipsis for long text',
        () {
          final snippet = SearchUtils.extractSnippet(
            pasal: pasalPanjang,
            query: 'seumur hidup',
          );

          expect(snippet.hasMatch, isTrue);
          expect(snippet.isFromPenjelasan, isFalse);
          expect(snippet.text.startsWith('... '), isTrue);
          expect(snippet.text, contains('seumur hidup'));
        },
      );

      test(
        'extracts snippet from penjelasan when match is only in penjelasan',
        () {
          final snippet = SearchUtils.extractSnippet(
            pasal: pasalPanjang,
            query: 'luka berat',
          );

          expect(snippet.hasMatch, isTrue);
          expect(snippet.isFromPenjelasan, isTrue);
          expect(snippet.text, contains('luka berat'));
        },
      );

      test('returns default isi for empty query or nomor search', () {
        final emptySnippet = SearchUtils.extractSnippet(
          pasal: pasalPanjang,
          query: '',
        );
        expect(emptySnippet.hasMatch, isFalse);
        expect(emptySnippet.isFromPenjelasan, isFalse);
        expect(emptySnippet.text.startsWith('(1) Setiap orang'), isTrue);

        final nomorSnippet = SearchUtils.extractSnippet(
          pasal: pasalPanjang,
          query: 'pasal 450',
        );
        expect(nomorSnippet.hasMatch, isFalse);
        expect(nomorSnippet.text.startsWith('(1) Setiap orang'), isTrue);
      });
    });
  });
}
