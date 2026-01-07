import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';

void main() {
  group('PasalModel', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final pasal = PasalModel(
          id: 'pasal-1',
          undangUndangId: 'uu-1',
          nomor: '1',
          isi: 'Isi pasal pertama',
        );

        expect(pasal.id, 'pasal-1');
        expect(pasal.undangUndangId, 'uu-1');
        expect(pasal.nomor, '1');
        expect(pasal.isi, 'Isi pasal pertama');
        expect(pasal.penjelasan, isNull);
        expect(pasal.judul, isNull);
        expect(pasal.keywords, isEmpty);
        expect(pasal.relatedIds, isEmpty);
        expect(pasal.isActive, isTrue);
        expect(pasal.createdAt, isNull);
        expect(pasal.updatedAt, isNull);
      });

      test('creates instance with all optional fields', () {
        final createdAt = DateTime(2025, 1, 15);
        final updatedAt = DateTime(2025, 1, 16);

        final pasal = PasalModel(
          id: 'pasal-1',
          undangUndangId: 'uu-1',
          nomor: '340',
          isi: 'Barang siapa dengan sengaja...',
          penjelasan: 'Penjelasan tentang pasal 340',
          judul: 'Pembunuhan Berencana',
          keywords: ['pembunuhan', 'berencana'],
          relatedIds: ['pasal-2', 'pasal-3'],
          isActive: false,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        expect(pasal.penjelasan, 'Penjelasan tentang pasal 340');
        expect(pasal.judul, 'Pembunuhan Berencana');
        expect(pasal.keywords, ['pembunuhan', 'berencana']);
        expect(pasal.relatedIds, ['pasal-2', 'pasal-3']);
        expect(pasal.isActive, isFalse);
        expect(pasal.createdAt, createdAt);
        expect(pasal.updatedAt, updatedAt);
      });
    });

    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'id': 'pasal-123',
          'undang_undang_id': 'uu-kuhp',
          'nomor': '340',
          'isi': 'Barang siapa dengan sengaja dan dengan rencana terlebih dahulu merampas nyawa orang lain',
          'penjelasan': 'Pasal ini mengatur tentang pembunuhan berencana',
          'judul': 'Pembunuhan Berencana',
          'keywords': ['pembunuhan', 'berencana', 'hukuman mati'],
          'related_ids': ['pasal-338', 'pasal-339'],
          'is_active': true,
          'created_at': '2025-01-15T10:00:00Z',
          'updated_at': '2025-01-16T15:30:00Z',
        };

        final pasal = PasalModel.fromJson(json);

        expect(pasal.id, 'pasal-123');
        expect(pasal.undangUndangId, 'uu-kuhp');
        expect(pasal.nomor, '340');
        expect(pasal.isi, contains('Barang siapa'));
        expect(pasal.penjelasan, contains('pembunuhan berencana'));
        expect(pasal.judul, 'Pembunuhan Berencana');
        expect(pasal.keywords, hasLength(3));
        expect(pasal.keywords, contains('pembunuhan'));
        expect(pasal.relatedIds, hasLength(2));
        expect(pasal.isActive, isTrue);
        expect(pasal.createdAt, isNotNull);
        expect(pasal.updatedAt, isNotNull);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'pasal-1',
          'undang_undang_id': 'uu-1',
          'nomor': '1',
          'isi': 'Isi pasal',
          'penjelasan': null,
          'judul': null,
          'keywords': null,
          'related_ids': null,
          'is_active': null,
          'created_at': null,
          'updated_at': null,
        };

        final pasal = PasalModel.fromJson(json);

        expect(pasal.penjelasan, isNull);
        expect(pasal.judul, isNull);
        expect(pasal.keywords, isEmpty);
        expect(pasal.relatedIds, isEmpty);
        expect(pasal.isActive, isTrue);
        expect(pasal.createdAt, isNull);
        expect(pasal.updatedAt, isNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final pasal = PasalModel.fromJson(json);

        expect(pasal.id, '');
        expect(pasal.undangUndangId, '');
        expect(pasal.nomor, '');
        expect(pasal.isi, '');
        expect(pasal.keywords, isEmpty);
        expect(pasal.relatedIds, isEmpty);
        expect(pasal.isActive, isTrue);
      });

      test('handles is_active false correctly', () {
        final json = {
          'id': 'pasal-1',
          'undang_undang_id': 'uu-1',
          'nomor': '1',
          'isi': 'Deleted pasal',
          'is_active': false,
        };

        final pasal = PasalModel.fromJson(json);

        expect(pasal.isActive, isFalse);
      });

      test('parses datetime strings correctly', () {
        final json = {
          'id': 'pasal-1',
          'undang_undang_id': 'uu-1',
          'nomor': '1',
          'isi': 'Isi pasal',
          'created_at': '2025-01-15T10:30:00.000Z',
          'updated_at': '2025-01-16T14:45:30.000Z',
        };

        final pasal = PasalModel.fromJson(json);

        expect(pasal.createdAt?.year, 2025);
        expect(pasal.createdAt?.month, 1);
        expect(pasal.createdAt?.day, 15);
        expect(pasal.updatedAt?.day, 16);
      });
    });
  });
}
