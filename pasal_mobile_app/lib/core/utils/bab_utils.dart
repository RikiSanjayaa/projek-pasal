import '../../models/pasal_model.dart';
import '../services/query_service.dart';
import 'search_utils.dart';

/// Satu bab di satu undang-undang, dengan jumlah pasal dan daftar judul di dalamnya.
class BabGroup {
  final String undangUndangId;
  final String bab;
  final int count;

  /// Judul pasal di bab ini yang berbeda dari judul bab, urut kemunculan.
  final List<BabJudul> juduls;

  const BabGroup({
    required this.undangUndangId,
    required this.bab,
    required this.count,
    required this.juduls,
  });

  /// Judul bab saja, tanpa buku dan nomor bab ("Tentang Hipotek").
  String get title => BabUtils.titleOf(bab);
}

class BabJudul {
  final String judul;
  final int count;

  const BabJudul(this.judul, this.count);
}

class BabUtils {
  static const String separator = ' · ';

  /// Bagian terakhir dari nilai bab: judul bab.
  static String titleOf(String bab) {
    final i = bab.lastIndexOf(separator);
    return i < 0 ? bab : bab.substring(i + separator.length);
  }

  /// Daftar bab per UU. Pasal diurutkan menurut UU ([uuOrder]) lalu nomor alami,
  /// jadi urutan bab mengikuti urutan undang-undang, bukan abjad.
  static List<BabGroup> groupsOf(
    Iterable<PasalModel> pasalList, {
    List<String> uuOrder = const [],
  }) {
    int uuRank(String id) {
      final i = uuOrder.indexOf(id);
      return i < 0 ? uuOrder.length : i;
    }

    final sorted = pasalList
        .where((p) => p.bab != null && p.bab!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final byUU = uuRank(a.undangUndangId).compareTo(uuRank(b.undangUndangId));
        if (byUU != 0) return byUU;
        final byId = a.undangUndangId.compareTo(b.undangUndangId);
        if (byId != 0) return byId;
        return QueryService.compareNomor(a.nomor, b.nomor);
      });

    final counts = <(String, String), int>{};
    final juduls = <(String, String), Map<String, int>>{};
    for (final p in sorted) {
      final key = (p.undangUndangId, p.bab!);
      counts[key] = (counts[key] ?? 0) + 1;
      final judul = p.judul?.trim() ?? '';
      if (judul.isNotEmpty &&
          SearchUtils.normalize(judul) !=
              SearchUtils.normalize(titleOf(p.bab!))) {
        final map = juduls.putIfAbsent(key, () => {});
        map[judul] = (map[judul] ?? 0) + 1;
      }
    }

    return [
      for (final e in counts.entries)
        BabGroup(
          undangUndangId: e.key.$1,
          bab: e.key.$2,
          count: e.value,
          juduls: [
            for (final j in (juduls[e.key] ?? const <String, int>{}).entries)
              BabJudul(j.key, j.value),
          ],
        ),
    ];
  }

  /// Pasal yang cocok dengan pilihan bab (dan judul bila dipilih).
  static bool matches(PasalModel p, String uuId, String bab, String? judul) =>
      p.undangUndangId == uuId &&
      p.bab == bab &&
      (judul == null || p.judul?.trim() == judul);
}
