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

      test('more specific multi-word query narrows results', () {
        // 6 pasal contain both tokens, 2 pasal only contain "seseorang".
        PasalModel make(String id, String isi) => PasalModel(
          id: id,
          undangUndangId: 'uu-1',
          nomor: id,
          isi: isi,
          keywords: const [],
        );
        final list = [
          for (var i = 1; i <= 6; i++)
            make('$i', 'Barangsiapa mengambil barang seseorang milik orang lain $i.'),
          make('7', 'Setiap seseorang wajib menghormati hak orang lain.'),
          make('8', 'Seseorang yang menyaksikan kejadian wajib lapor.'),
        ];

        final broad = SearchUtils.rankPasal(list, 'mengambil barang');
        final specific = SearchUtils.rankPasal(list, 'mengambil barang seseorang');

        expect(broad.length, 6);
        expect(specific.length, 6); // narrowed, not widened: seseorang-only pasal dropped
      });
    });

    group('smart suggestions', () {
      test('returns legal suggestions for everyday words', () {
        final suggestions = SearchUtils.suggestionsForQuery('maling');
        expect(suggestions, contains('pencurian'));
        expect(suggestions, contains('mengambil barang'));
      });

      test('data suggestions rank exact then substring then fuzzy', () {
        final list = [
          PasalModel(
            id: '1',
            undangUndangId: 'uu-1',
            nomor: '362',
            judul: 'Pencurian barang',
            isi: 'Mencuri.',
            keywords: const ['pencurian', 'barang bergerak'],
          ),
          PasalModel(
            id: '2',
            undangUndangId: 'uu-1',
            nomor: '167',
            judul: 'Pencurian dengan kekerasan',
            isi: 'Melanggar ketentuan.',
            keywords: const ['keras'],
          ),
          PasalModel(
            id: '3',
            undangUndangId: 'uu-1',
            nomor: '480',
            isi: 'Penadahan.',
            keywords: const ['penadahan'],
          ),
        ];

        // Exact token match wins over substring; titles and keywords both suggested.
        final result = SearchUtils.suggestionsFromData('pencurian', list);
        expect(result.first, 'pencurian');
        expect(result, contains('pencurian barang'));
        expect(result, contains('pencurian dengan kekerasan'));

        // Typo falls back to fuzzy keyword match.
        final typo = SearchUtils.suggestionsFromData('pencurianx', list);
        expect(typo, contains('pencurian'));

        // No relevant keyword → empty (no dud suggestions).
        expect(SearchUtils.suggestionsFromData('meteorologi', list), isEmpty);
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

    group('multi-UU search', () {
      PasalModel make(String uu, String nomor, String isi, {String? penjelasan}) => PasalModel(
        id: '$uu-$nomor',
        undangUndangId: uu,
        nomor: nomor,
        isi: isi,
        penjelasan: penjelasan,
      );

      final kode = {'uu-kuhp': 'KUHP', 'uu-kuhper': 'KUHPER'};
      final list = [
        make('uu-kuhp', '1', '(1) Tidak ada satu perbuatan pun yang dapat dikenai sanksi pidana.'),
        make('uu-kuhp', '362', 'Setiap Orang yang menggunakan gelar tanpa hak.'),
        make('uu-kuhper', '362', 'Pengadilan dapat menunjuk wali.'),
        make('uu-kuhper', '1365', 'Tiap perbuatan melanggar hukum yang membawa kerugian kepada orang lain.'),
        make(
          'uu-kuhper',
          '594',
          'Hak milik atas benda diperoleh karena pengambilan untuk dimiliki.',
          penjelasan: 'Catatan CariPasal: UU 5/1960 mencabut Buku II sepanjang mengenai tanah dan perkawinan.',
        ),
        make('uu-kuhper', '26', 'Undang-undang memandang perkawinan hanya dalam hubungan perdata.'),
      ];

      test('pasal number with ayat goes straight to that pasal', () {
        final result = SearchUtils.rankPasal(list, 'pasal 1 ayat (1)');
        expect(result.map((p) => p.id), ['uu-kuhp-1']);
      });

      test('naming the UU narrows a number search to that UU', () {
        final result = SearchUtils.rankPasal(list, 'pasal 362 kuhper', kodeByUuId: kode);
        expect(result.map((p) => p.id), ['uu-kuhper-362']);
      });

      test('UU alias (kuhperdata) works and does not match KUHP by prefix', () {
        final result = SearchUtils.rankPasal(list, 'pasal 1365 kuhperdata', kodeByUuId: kode);
        expect(result.map((p) => p.id), ['uu-kuhper-1365']);
        final kuhp = SearchUtils.rankPasal(list, '362 kuhp', kodeByUuId: kode);
        expect(kuhp.map((p) => p.id), ['uu-kuhp-362']);
      });

      test('Catatan CariPasal lines in penjelasan are not searched', () {
        final result = SearchUtils.rankPasal(list, 'perkawinan');
        expect(result.map((p) => p.id), ['uu-kuhper-26']);
      });

      test('correctQuery fixes a typo to a word that exists in the data', () {
        expect(SearchUtils.correctQuery('perbuatn melanggar hukum', list), 'perbuatan melanggar hukum');
        expect(SearchUtils.correctQuery('perkawinan', list), isNull);
        expect(SearchUtils.correctQuery('pasal 1365', list), isNull);
      });
    });

    group('match tiers', () {
      PasalModel make(String id, String isi) => PasalModel(id: id, undangUndangId: 'uu-1', nomor: id, isi: isi);

      final phrase = make('1', 'Setiap orang yang melakukan pencemaran nama baik dipidana.');
      final scattered = make('2', 'Pencemaran terhadap nama seseorang yang baik dan terhormat.');
      final partial = make('3', 'Perbaikan nama jalan dilakukan oleh pemerintah daerah.');

      test('exact phrase first, then all words scattered, then partial', () {
        final result = SearchUtils.search([partial, scattered, phrase], 'pencemaran nama baik');
        expect(result.pasal.map((p) => p.id), ['1', '2', '3']);
        expect(result.tierOf(phrase), SearchMatchTier.phrase);
        expect(result.tierOf(scattered), SearchMatchTier.allWords);
        // "baik" di dalam "perbaikan" bukan awal kata, jadi tidak dihitung sebagai kata yang cocok.
        expect(result.tierOf(partial), SearchMatchTier.partial);
        expect(result.hasPhraseMatch, isTrue);
      });

      test('reports when no pasal has the exact phrase', () {
        final result = SearchUtils.search([partial, scattered], 'pencemaran nama baik');
        expect(result.isTiered, isTrue);
        expect(result.hasPhraseMatch, isFalse);
        expect(result.pasal.first.id, '2');
      });

      test('partial matches are dropped once five pasal match every word', () {
        final strong = [for (var i = 10; i < 15; i++) make('$i', 'Pencemaran nama orang yang baik.')];
        final result = SearchUtils.search([...strong, partial], 'pencemaran nama baik');
        expect(result.pasal.map((p) => p.id), isNot(contains('3')));
      });

      test('single-word queries are not grouped', () {
        final result = SearchUtils.search([phrase, scattered], 'pencemaran');
        expect(result.isTiered, isFalse);
        expect(result.tierOf(phrase), isNull);
      });

      test('alias of the whole query forms its own group after the exact phrase', () {
        SearchUtils.applyServerAliases([
          {'term': 'kumpul kebo', 'aliases': ['hidup bersama sebagai suami istri']},
        ]);
        final alias = make('20', 'Setiap Orang yang melakukan hidup bersama sebagai suami istri di luar perkawinan.');
        final other = make('21', 'Perkumpulan dapat menjadi wali.');
        final result = SearchUtils.search([other, alias], 'kumpul kebo');
        expect(result.pasal.first.id, '20');
        expect(result.tierOf(alias), SearchMatchTier.alias);
        expect(result.aliases, ['hidup bersama sebagai suami istri']);
      });
    });
  });
}
