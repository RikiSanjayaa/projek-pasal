import 'package:mockito/mockito.dart';
import 'package:pasal_mobile_app/core/database/app_database.dart';

/// Mock class for AppDatabase used in unit tests.
///
/// This mock allows testing services that depend on AppDatabase
/// without requiring an actual SQLite database.
class MockAppDatabase extends Mock implements AppDatabase {}

/// Helper class to create test data for database operations.
class TestDataFactory {
  /// Create a sample UndangUndangTableData for testing.
  static UndangUndangTableData createUndangUndang({
    String id = 'uu-1',
    String kode = 'KUHP',
    String nama = 'Kitab Undang-Undang Hukum Pidana',
    String? namaLengkap = 'Kitab Undang-Undang Hukum Pidana Indonesia',
    String? deskripsi = 'Hukum pidana umum',
    int tahun = 2023,
    bool isActive = true,
    DateTime? updatedAt,
  }) {
    return UndangUndangTableData(
      id: id,
      kode: kode,
      nama: nama,
      namaLengkap: namaLengkap,
      deskripsi: deskripsi,
      tahun: tahun,
      isActive: isActive,
      updatedAt: updatedAt ?? DateTime(2024, 1, 1),
    );
  }

  /// Create a sample PasalTableData for testing.
  static PasalTableData createPasal({
    String id = 'pasal-1',
    String undangUndangId = 'uu-1',
    String nomor = '1',
    String isi = 'Isi pasal 1',
    String? penjelasan = 'Penjelasan pasal 1',
    String? judul = 'Judul pasal 1',
    String keywords = '["keyword1", "keyword2"]',
    String relatedIds = '[]',
    bool isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PasalTableData(
      id: id,
      undangUndangId: undangUndangId,
      nomor: nomor,
      isi: isi,
      penjelasan: penjelasan,
      judul: judul,
      keywords: keywords,
      relatedIds: relatedIds,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a sample PasalLinksTableData for testing.
  static PasalLinksTableData createPasalLink({
    String id = 'link-1',
    String sourcePasalId = 'pasal-1',
    String targetPasalId = 'pasal-2',
    String? keterangan = 'Lihat juga',
    bool isActive = true,
    DateTime? createdAt,
  }) {
    return PasalLinksTableData(
      id: id,
      sourcePasalId: sourcePasalId,
      targetPasalId: targetPasalId,
      keterangan: keterangan,
      isActive: isActive,
      createdAt: createdAt ?? DateTime(2024, 1, 1),
    );
  }

  /// Create multiple UndangUndang for testing list operations.
  static List<UndangUndangTableData> createUndangUndangList(int count) {
    return List.generate(
      count,
      (i) => createUndangUndang(
        id: 'uu-$i',
        kode: 'UU$i',
        nama: 'Undang-Undang $i',
        tahun: 2020 + i,
      ),
    );
  }

  /// Create multiple Pasal for testing list operations.
  static List<PasalTableData> createPasalList(int count, {String uuId = 'uu-1'}) {
    return List.generate(
      count,
      (i) => createPasal(
        id: 'pasal-$i',
        undangUndangId: uuId,
        nomor: '${i + 1}',
        isi: 'Isi pasal ${i + 1}',
      ),
    );
  }

  /// Create multiple PasalLinks for testing.
  static List<PasalLinksTableData> createPasalLinksList(
    String sourcePasalId,
    List<String> targetPasalIds,
  ) {
    return targetPasalIds.asMap().entries.map((entry) {
      return createPasalLink(
        id: 'link-${entry.key}',
        sourcePasalId: sourcePasalId,
        targetPasalId: entry.value,
        keterangan: 'Relasi ke ${entry.value}',
      );
    }).toList();
  }
}
