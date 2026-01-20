import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile_app/models/pasal_model.dart';
import 'package:pasal_mobile_app/models/pasal_link_model.dart';

void main() {
  group('PasalLinkModel', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final link = PasalLinkModel(
          id: 'link-1',
          sourcePasalId: 'pasal-1',
          targetPasalId: 'pasal-2',
        );

        expect(link.id, 'link-1');
        expect(link.sourcePasalId, 'pasal-1');
        expect(link.targetPasalId, 'pasal-2');
        expect(link.keterangan, isNull);
        expect(link.isActive, isTrue);
        expect(link.createdAt, isNull);
      });

      test('creates instance with all optional fields', () {
        final createdAt = DateTime(2025, 1, 15);

        final link = PasalLinkModel(
          id: 'link-1',
          sourcePasalId: 'pasal-1',
          targetPasalId: 'pasal-2',
          keterangan: 'Lihat juga',
          isActive: false,
          createdAt: createdAt,
        );

        expect(link.keterangan, 'Lihat juga');
        expect(link.isActive, isFalse);
        expect(link.createdAt, createdAt);
      });
    });

    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'id': 'link-123',
          'source_pasal_id': 'pasal-340',
          'target_pasal_id': 'pasal-338',
          'keterangan': 'Terkait dengan',
          'is_active': true,
          'created_at': '2025-01-15T10:00:00Z',
        };

        final link = PasalLinkModel.fromJson(json);

        expect(link.id, 'link-123');
        expect(link.sourcePasalId, 'pasal-340');
        expect(link.targetPasalId, 'pasal-338');
        expect(link.keterangan, 'Terkait dengan');
        expect(link.isActive, isTrue);
        expect(link.createdAt, isNotNull);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'link-1',
          'source_pasal_id': 'pasal-1',
          'target_pasal_id': 'pasal-2',
          'keterangan': null,
          'is_active': null,
          'created_at': null,
        };

        final link = PasalLinkModel.fromJson(json);

        expect(link.keterangan, isNull);
        expect(link.isActive, isTrue);
        expect(link.createdAt, isNull);
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final link = PasalLinkModel.fromJson(json);

        expect(link.id, '');
        expect(link.sourcePasalId, '');
        expect(link.targetPasalId, '');
        expect(link.isActive, isTrue);
      });

      test('handles is_active false correctly', () {
        final json = {
          'id': 'link-1',
          'source_pasal_id': 'pasal-1',
          'target_pasal_id': 'pasal-2',
          'is_active': false,
        };

        final link = PasalLinkModel.fromJson(json);

        expect(link.isActive, isFalse);
      });
    });
  });

  group('PasalLinkWithTarget', () {
    test('creates instance with target pasal and keterangan', () {
      final targetPasal = PasalModel(
        id: 'pasal-2',
        undangUndangId: 'uu-1',
        nomor: '338',
        isi: 'Isi pasal 338',
      );

      final linkWithTarget = PasalLinkWithTarget(
        targetPasal: targetPasal,
        keterangan: 'Lihat juga',
      );

      expect(linkWithTarget.targetPasal.id, 'pasal-2');
      expect(linkWithTarget.targetPasal.nomor, '338');
      expect(linkWithTarget.keterangan, 'Lihat juga');
    });

    test('creates instance with null keterangan', () {
      final targetPasal = PasalModel(
        id: 'pasal-2',
        undangUndangId: 'uu-1',
        nomor: '338',
        isi: 'Isi pasal 338',
      );

      final linkWithTarget = PasalLinkWithTarget(
        targetPasal: targetPasal,
      );

      expect(linkWithTarget.targetPasal.id, 'pasal-2');
      expect(linkWithTarget.keterangan, isNull);
    });
  });
}
