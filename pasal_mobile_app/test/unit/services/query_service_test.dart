import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:pasal_mobile_app/core/database/app_database.dart';
import 'package:pasal_mobile_app/core/services/query_service.dart';
// Import only TestDataFactory from the mock file, using show
import '../../mocks/app_database_mock.dart' show TestDataFactory;

@GenerateMocks([AppDatabase])
import 'query_service_test.mocks.dart';

void main() {
  late MockAppDatabase mockDatabase;

  setUp(() {
    mockDatabase = MockAppDatabase();
    QueryService.initialize(mockDatabase);
  });

  group('QueryService - UndangUndang Queries', () {
    group('getAllUU', () {
      test(
        'returns list of UndangUndangModel when database has data',
        () async {
          final testData = [
            TestDataFactory.createUndangUndang(id: 'uu-1', kode: 'KUHP'),
            TestDataFactory.createUndangUndang(id: 'uu-2', kode: 'KUHPer'),
          ];
          when(
            mockDatabase.getActiveUndangUndang(),
          ).thenAnswer((_) async => testData);

          final result = await QueryService.getAllUU();

          expect(result.length, 2);
          expect(result[0].id, 'uu-1');
          expect(result[0].kode, 'KUHP');
          expect(result[1].id, 'uu-2');
          expect(result[1].kode, 'KUHPer');
          verify(mockDatabase.getActiveUndangUndang()).called(1);
        },
      );

      test('returns empty list when database is empty', () async {
        when(mockDatabase.getActiveUndangUndang()).thenAnswer((_) async => []);

        final result = await QueryService.getAllUU();

        expect(result, isEmpty);
        verify(mockDatabase.getActiveUndangUndang()).called(1);
      });

      test('returns empty list when database throws exception', () async {
        when(
          mockDatabase.getActiveUndangUndang(),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getAllUU();

        expect(result, isEmpty);
      });

      test('correctly maps all UndangUndang fields', () async {
        final testData = [
          TestDataFactory.createUndangUndang(
            id: 'uu-test',
            kode: 'TEST',
            nama: 'Test Law',
            namaLengkap: 'Test Law Full Name',
            deskripsi: 'Test Description',
            tahun: 2024,
            isActive: true,
            updatedAt: DateTime(2024, 6, 15),
          ),
        ];
        when(
          mockDatabase.getActiveUndangUndang(),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.getAllUU();

        expect(result.length, 1);
        final uu = result.first;
        expect(uu.id, 'uu-test');
        expect(uu.kode, 'TEST');
        expect(uu.nama, 'Test Law');
        expect(uu.namaLengkap, 'Test Law Full Name');
        expect(uu.deskripsi, 'Test Description');
        expect(uu.tahun, 2024);
        expect(uu.isActive, true);
        expect(uu.updatedAt, DateTime(2024, 6, 15));
      });
    });

    group('getUUById', () {
      test('returns UndangUndangModel when found', () async {
        final testData = TestDataFactory.createUndangUndang(
          id: 'uu-1',
          kode: 'KUHP',
        );
        when(
          mockDatabase.getUndangUndangById('uu-1'),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.getUUById('uu-1');

        expect(result, isNotNull);
        expect(result!.id, 'uu-1');
        expect(result.kode, 'KUHP');
        verify(mockDatabase.getUndangUndangById('uu-1')).called(1);
      });

      test('returns null when not found', () async {
        when(
          mockDatabase.getUndangUndangById('non-existent'),
        ).thenAnswer((_) async => null);

        final result = await QueryService.getUUById('non-existent');

        expect(result, isNull);
      });

      test('returns null when database throws exception', () async {
        when(
          mockDatabase.getUndangUndangById('uu-1'),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getUUById('uu-1');

        expect(result, isNull);
      });
    });

    group('getKodeUU', () {
      test('returns kode when UU found', () async {
        final testData = TestDataFactory.createUndangUndang(
          id: 'uu-1',
          kode: 'KUHP',
        );
        when(
          mockDatabase.getUndangUndangById('uu-1'),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.getKodeUU('uu-1');

        expect(result, 'KUHP');
      });

      test('returns "UU" when not found', () async {
        when(
          mockDatabase.getUndangUndangById('non-existent'),
        ).thenAnswer((_) async => null);

        final result = await QueryService.getKodeUU('non-existent');

        expect(result, 'UU');
      });

      test('returns "UU" when database throws exception', () async {
        when(
          mockDatabase.getUndangUndangById('uu-1'),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getKodeUU('uu-1');

        expect(result, 'UU');
      });
    });
  });

  group('QueryService - Pasal Queries', () {
    group('getAllPasal', () {
      test('returns list of PasalModel when database has data', () async {
        final testData = [
          TestDataFactory.createPasal(id: 'pasal-1', nomor: '1'),
          TestDataFactory.createPasal(id: 'pasal-2', nomor: '2'),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getAllPasal();

        expect(result.length, 2);
        expect(result[0].id, 'pasal-1');
        expect(result[1].id, 'pasal-2');
        verify(mockDatabase.getActivePasal()).called(1);
      });

      test('returns empty list when database is empty', () async {
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => []);

        final result = await QueryService.getAllPasal();

        expect(result, isEmpty);
      });

      test('returns empty list when database throws exception', () async {
        when(mockDatabase.getActivePasal()).thenThrow(Exception('DB Error'));

        final result = await QueryService.getAllPasal();

        expect(result, isEmpty);
      });

      test('correctly parses keywords JSON array', () async {
        final testData = [
          TestDataFactory.createPasal(
            id: 'pasal-1',
            keywords: '["pidana", "hukum", "sanksi"]',
          ),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getAllPasal();

        expect(result.first.keywords, ['pidana', 'hukum', 'sanksi']);
      });

      test('returns empty list for invalid keywords JSON', () async {
        final testData = [
          TestDataFactory.createPasal(id: 'pasal-1', keywords: 'invalid json'),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getAllPasal();

        expect(result.first.keywords, isEmpty);
      });

      test('returns empty list for empty keywords string', () async {
        final testData = [
          TestDataFactory.createPasal(id: 'pasal-1', keywords: ''),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getAllPasal();

        expect(result.first.keywords, isEmpty);
      });

      test('returns empty list for empty array keywords', () async {
        final testData = [
          TestDataFactory.createPasal(id: 'pasal-1', keywords: '[]'),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getAllPasal();

        expect(result.first.keywords, isEmpty);
      });
    });

    group('searchPasal', () {
      test('returns matching results for valid query', () async {
        final testData = [
          TestDataFactory.createPasal(id: 'pasal-1', isi: 'Hukum pidana'),
        ];
        when(
          mockDatabase.searchActivePasal('pidana'),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.searchPasal('pidana');

        expect(result.length, 1);
        expect(result.first.id, 'pasal-1');
        verify(mockDatabase.searchActivePasal('pidana')).called(1);
      });

      test('returns empty list for empty query', () async {
        final result = await QueryService.searchPasal('');

        expect(result, isEmpty);
        verifyNever(mockDatabase.searchActivePasal(any));
      });

      test('returns empty list when no matches found', () async {
        when(
          mockDatabase.searchActivePasal('nonexistent'),
        ).thenAnswer((_) async => []);

        final result = await QueryService.searchPasal('nonexistent');

        expect(result, isEmpty);
      });

      test('returns empty list when database throws exception', () async {
        when(
          mockDatabase.searchActivePasal('query'),
        ).thenThrow(Exception('Search Error'));

        final result = await QueryService.searchPasal('query');

        expect(result, isEmpty);
      });
    });

    group('getPasalById', () {
      test('returns PasalModel when found', () async {
        final testData = TestDataFactory.createPasal(id: 'pasal-1', nomor: '1');
        when(
          mockDatabase.getPasalById('pasal-1'),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.getPasalById('pasal-1');

        expect(result, isNotNull);
        expect(result!.id, 'pasal-1');
        expect(result.nomor, '1');
      });

      test('returns null when not found', () async {
        when(
          mockDatabase.getPasalById('non-existent'),
        ).thenAnswer((_) async => null);

        final result = await QueryService.getPasalById('non-existent');

        expect(result, isNull);
      });

      test('returns null when database throws exception', () async {
        when(
          mockDatabase.getPasalById('pasal-1'),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getPasalById('pasal-1');

        expect(result, isNull);
      });
    });

    group('getPasalByUU', () {
      test('returns list of pasal for given UU id', () async {
        final testData = [
          TestDataFactory.createPasal(id: 'pasal-1', undangUndangId: 'uu-1'),
          TestDataFactory.createPasal(id: 'pasal-2', undangUndangId: 'uu-1'),
        ];
        when(
          mockDatabase.getActivePasalByUndangUndang('uu-1'),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.getPasalByUU('uu-1');

        expect(result.length, 2);
        expect(result.every((p) => p.undangUndangId == 'uu-1'), true);
      });

      test('returns empty list when UU has no pasal', () async {
        when(
          mockDatabase.getActivePasalByUndangUndang('uu-empty'),
        ).thenAnswer((_) async => []);

        final result = await QueryService.getPasalByUU('uu-empty');

        expect(result, isEmpty);
      });

      test('returns empty list when database throws exception', () async {
        when(
          mockDatabase.getActivePasalByUndangUndang('uu-1'),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getPasalByUU('uu-1');

        expect(result, isEmpty);
      });
    });

    group('getPasalByKeyword', () {
      test('returns matching pasal for keyword', () async {
        final testData = [TestDataFactory.createPasal(id: 'pasal-1')];
        when(
          mockDatabase.searchActivePasal('pidana'),
        ).thenAnswer((_) async => testData);

        final result = await QueryService.getPasalByKeyword('pidana');

        expect(result.length, 1);
        verify(mockDatabase.searchActivePasal('pidana')).called(1);
      });

      test('returns empty list when database throws exception', () async {
        when(
          mockDatabase.searchActivePasal('keyword'),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getPasalByKeyword('keyword');

        expect(result, isEmpty);
      });
    });

    group('getLatestUpdates', () {
      test('returns pasal sorted by updatedAt descending', () async {
        final now = DateTime.now();
        final testData = [
          TestDataFactory.createPasal(
            id: 'pasal-1',
            updatedAt: now.subtract(const Duration(days: 2)),
          ),
          TestDataFactory.createPasal(
            id: 'pasal-2',
            updatedAt: now.subtract(const Duration(days: 1)),
          ),
          TestDataFactory.createPasal(id: 'pasal-3', updatedAt: now),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getLatestUpdates(limit: 3);

        expect(result.length, 3);
        expect(result[0].id, 'pasal-3'); // Most recent first
        expect(result[1].id, 'pasal-2');
        expect(result[2].id, 'pasal-1');
      });

      test('respects limit parameter', () async {
        final testData = TestDataFactory.createPasalList(10);
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getLatestUpdates(limit: 5);

        expect(result.length, 5);
      });

      test('uses default limit of 5', () async {
        final testData = TestDataFactory.createPasalList(10);
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getLatestUpdates();

        expect(result.length, 5);
      });

      test('returns empty list when database throws exception', () async {
        when(mockDatabase.getActivePasal()).thenThrow(Exception('DB Error'));

        final result = await QueryService.getLatestUpdates();

        expect(result, isEmpty);
      });

      test('handles pasal with null updatedAt by using createdAt', () async {
        final now = DateTime.now();
        // Create test data directly to ensure null values are set correctly
        final testData = [
          PasalTableData(
            id: 'pasal-1',
            undangUndangId: 'uu-1',
            nomor: '1',
            isi: 'Isi 1',
            keywords: '[]',
            relatedIds: '[]',
            isActive: true,
            createdAt: now.subtract(const Duration(days: 1)),
            updatedAt: null,
          ),
          PasalTableData(
            id: 'pasal-2',
            undangUndangId: 'uu-1',
            nomor: '2',
            isi: 'Isi 2',
            keywords: '[]',
            relatedIds: '[]',
            isActive: true,
            createdAt: now,
            updatedAt: null,
          ),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getLatestUpdates(limit: 2);

        expect(result[0].id, 'pasal-2'); // More recent createdAt
        expect(result[1].id, 'pasal-1');
      });

      test('handles pasal with both null dates', () async {
        // Create test data directly to ensure null values are set correctly
        final testData = [
          PasalTableData(
            id: 'pasal-1',
            undangUndangId: 'uu-1',
            nomor: '1',
            isi: 'Isi 1',
            keywords: '[]',
            relatedIds: '[]',
            isActive: true,
            createdAt: null,
            updatedAt: null,
          ),
          PasalTableData(
            id: 'pasal-2',
            undangUndangId: 'uu-1',
            nomor: '2',
            isi: 'Isi 2',
            keywords: '[]',
            relatedIds: '[]',
            isActive: true,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: null,
          ),
        ];
        when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

        final result = await QueryService.getLatestUpdates(limit: 2);

        // pasal-2 should come first as it has a valid date
        expect(result[0].id, 'pasal-2');
        expect(result[1].id, 'pasal-1');
      });
    });
  });

  group('QueryService - Pasal Links Queries', () {
    group('getPasalLinks', () {
      test('returns links with target pasal info', () async {
        final links = [
          TestDataFactory.createPasalLink(
            id: 'link-1',
            sourcePasalId: 'pasal-1',
            targetPasalId: 'pasal-2',
            keterangan: 'Lihat juga',
          ),
        ];
        final targetPasal = TestDataFactory.createPasal(
          id: 'pasal-2',
          nomor: '2',
        );

        when(
          mockDatabase.getLinksBySourcePasal('pasal-1'),
        ).thenAnswer((_) async => links);
        when(
          mockDatabase.getPasalById('pasal-2'),
        ).thenAnswer((_) async => targetPasal);

        final result = await QueryService.getPasalLinks('pasal-1');

        expect(result.length, 1);
        expect(result.first.targetPasal.id, 'pasal-2');
        expect(result.first.keterangan, 'Lihat juga');
      });

      test('skips links where target pasal not found', () async {
        final links = [
          TestDataFactory.createPasalLink(
            sourcePasalId: 'pasal-1',
            targetPasalId: 'pasal-missing',
          ),
          TestDataFactory.createPasalLink(
            id: 'link-2',
            sourcePasalId: 'pasal-1',
            targetPasalId: 'pasal-2',
          ),
        ];
        final targetPasal = TestDataFactory.createPasal(id: 'pasal-2');

        when(
          mockDatabase.getLinksBySourcePasal('pasal-1'),
        ).thenAnswer((_) async => links);
        when(
          mockDatabase.getPasalById('pasal-missing'),
        ).thenAnswer((_) async => null);
        when(
          mockDatabase.getPasalById('pasal-2'),
        ).thenAnswer((_) async => targetPasal);

        final result = await QueryService.getPasalLinks('pasal-1');

        expect(result.length, 1);
        expect(result.first.targetPasal.id, 'pasal-2');
      });

      test('returns empty list when no links exist', () async {
        when(
          mockDatabase.getLinksBySourcePasal('pasal-1'),
        ).thenAnswer((_) async => []);

        final result = await QueryService.getPasalLinks('pasal-1');

        expect(result, isEmpty);
      });

      test('returns empty list when database throws exception', () async {
        when(
          mockDatabase.getLinksBySourcePasal('pasal-1'),
        ).thenThrow(Exception('DB Error'));

        final result = await QueryService.getPasalLinks('pasal-1');

        expect(result, isEmpty);
      });

      test('handles multiple links correctly', () async {
        final links = [
          TestDataFactory.createPasalLink(
            id: 'link-1',
            sourcePasalId: 'pasal-1',
            targetPasalId: 'pasal-2',
            keterangan: 'Referensi 1',
          ),
          TestDataFactory.createPasalLink(
            id: 'link-2',
            sourcePasalId: 'pasal-1',
            targetPasalId: 'pasal-3',
            keterangan: 'Referensi 2',
          ),
        ];
        final target2 = TestDataFactory.createPasal(id: 'pasal-2', nomor: '2');
        final target3 = TestDataFactory.createPasal(id: 'pasal-3', nomor: '3');

        when(
          mockDatabase.getLinksBySourcePasal('pasal-1'),
        ).thenAnswer((_) async => links);
        when(
          mockDatabase.getPasalById('pasal-2'),
        ).thenAnswer((_) async => target2);
        when(
          mockDatabase.getPasalById('pasal-3'),
        ).thenAnswer((_) async => target3);

        final result = await QueryService.getPasalLinks('pasal-1');

        expect(result.length, 2);
        expect(result[0].targetPasal.nomor, '2');
        expect(result[0].keterangan, 'Referensi 1');
        expect(result[1].targetPasal.nomor, '3');
        expect(result[1].keterangan, 'Referensi 2');
      });
    });
  });

  group('QueryService - Data Transformation', () {
    test('correctly maps all PasalModel fields', () async {
      final testData = [
        TestDataFactory.createPasal(
          id: 'pasal-test',
          undangUndangId: 'uu-test',
          nomor: '123A',
          isi: 'Test content',
          penjelasan: 'Test explanation',
          judul: 'Test title',
          keywords: '["test", "sample"]',
          relatedIds: '["rel-1", "rel-2"]',
          isActive: true,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 6, 15),
        ),
      ];
      when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

      final result = await QueryService.getAllPasal();

      expect(result.length, 1);
      final pasal = result.first;
      expect(pasal.id, 'pasal-test');
      expect(pasal.undangUndangId, 'uu-test');
      expect(pasal.nomor, '123A');
      expect(pasal.isi, 'Test content');
      expect(pasal.penjelasan, 'Test explanation');
      expect(pasal.judul, 'Test title');
      expect(pasal.keywords, ['test', 'sample']);
      expect(pasal.relatedIds, ['rel-1', 'rel-2']);
      expect(pasal.isActive, true);
      expect(pasal.createdAt, DateTime(2024, 1, 1));
      expect(pasal.updatedAt, DateTime(2024, 6, 15));
    });

    test('handles nullable fields correctly', () async {
      final testData = [
        TestDataFactory.createPasal(
          id: 'pasal-test',
          penjelasan: null,
          judul: null,
          createdAt: null,
          updatedAt: null,
        ),
      ];
      when(mockDatabase.getActivePasal()).thenAnswer((_) async => testData);

      final result = await QueryService.getAllPasal();

      expect(result.first.penjelasan, isNull);
      expect(result.first.judul, isNull);
      expect(result.first.createdAt, isNull);
      expect(result.first.updatedAt, isNull);
    });
  });
}
