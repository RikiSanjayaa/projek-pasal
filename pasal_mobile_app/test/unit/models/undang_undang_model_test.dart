import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/models/undang_undang_model.dart';

void main() {
  group('UndangUndangModel', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final uu = UndangUndangModel(
          id: 'uu-1',
          kode: 'KUHP',
          nama: 'Kitab Undang-Undang Hukum Pidana',
          tahun: 2023,
          isActive: true,
        );

        expect(uu.id, 'uu-1');
        expect(uu.kode, 'KUHP');
        expect(uu.nama, 'Kitab Undang-Undang Hukum Pidana');
        expect(uu.tahun, 2023);
        expect(uu.isActive, isTrue);
        expect(uu.namaLengkap, isNull);
        expect(uu.deskripsi, isNull);
        expect(uu.updatedAt, isNull);
      });

      test('creates instance with all optional fields', () {
        final updatedAt = DateTime(2025, 1, 15);

        final uu = UndangUndangModel(
          id: 'uu-1',
          kode: 'KUHP',
          nama: 'KUHP',
          namaLengkap: 'Kitab Undang-Undang Hukum Pidana Indonesia',
          deskripsi: 'Kodifikasi hukum pidana nasional',
          tahun: 2023,
          isActive: true,
          updatedAt: updatedAt,
        );

        expect(uu.namaLengkap, 'Kitab Undang-Undang Hukum Pidana Indonesia');
        expect(uu.deskripsi, 'Kodifikasi hukum pidana nasional');
        expect(uu.updatedAt, updatedAt);
      });
    });

    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'id': 'uu-kuhp',
          'kode': 'KUHP',
          'nama': 'Kitab Undang-Undang Hukum Pidana',
          'nama_lengkap': 'Kitab Undang-Undang Hukum Pidana Republik Indonesia',
          'deskripsi': 'Hukum pidana yang berlaku di Indonesia sejak 2023',
          'tahun': 2023,
          'is_active': true,
          'updated_at': '2025-01-15T12:00:00Z',
        };

        final uu = UndangUndangModel.fromJson(json);

        expect(uu.id, 'uu-kuhp');
        expect(uu.kode, 'KUHP');
        expect(uu.nama, 'Kitab Undang-Undang Hukum Pidana');
        expect(uu.namaLengkap, contains('Republik Indonesia'));
        expect(uu.deskripsi, contains('2023'));
        expect(uu.tahun, 2023);
        expect(uu.isActive, isTrue);
        expect(uu.updatedAt, isNotNull);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'uu-1',
          'kode': 'TEST',
          'nama': 'Test UU',
          'nama_lengkap': null,
          'deskripsi': null,
          'tahun': 2020,
          'is_active': true,
          'updated_at': null,
        };

        final uu = UndangUndangModel.fromJson(json);

        expect(uu.namaLengkap, isNull);
        expect(uu.deskripsi, isNull);
        expect(uu.updatedAt, isNull);
      });

      test('handles null tahun with default value 0', () {
        final json = {
          'id': 'uu-1',
          'kode': 'TEST',
          'nama': 'Test UU',
          'tahun': null,
          'is_active': true,
        };

        final uu = UndangUndangModel.fromJson(json);

        expect(uu.tahun, 0);
      });

      test('handles is_active default to true', () {
        final json = {
          'id': 'uu-1',
          'kode': 'TEST',
          'nama': 'Test UU',
          'tahun': 2020,
        };

        final uu = UndangUndangModel.fromJson(json);

        expect(uu.isActive, isTrue);
      });

      test('handles is_active false correctly', () {
        final json = {
          'id': 'uu-1',
          'kode': 'TEST',
          'nama': 'Deleted UU',
          'tahun': 2020,
          'is_active': false,
        };

        final uu = UndangUndangModel.fromJson(json);

        expect(uu.isActive, isFalse);
      });

      test('parses datetime string correctly', () {
        final json = {
          'id': 'uu-1',
          'kode': 'TEST',
          'nama': 'Test UU',
          'tahun': 2020,
          'is_active': true,
          'updated_at': '2025-06-15T14:30:00.000Z',
        };

        final uu = UndangUndangModel.fromJson(json);

        expect(uu.updatedAt?.year, 2025);
        expect(uu.updatedAt?.month, 6);
        expect(uu.updatedAt?.day, 15);
      });
    });
  });
}
