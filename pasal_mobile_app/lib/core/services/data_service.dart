import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/undang_undang_model.dart';
import '../../models/pasal_model.dart';

class DataService {
  static const String boxUU = 'undang_undang_box';
  static final SupabaseClient supabase = Supabase.instance.client;
  
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UndangUndangModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PasalModelAdapter());

    await Hive.openBox<UndangUndangModel>(boxUU);

    final boxUUInstance = Hive.box<UndangUndangModel>(boxUU);
    if (boxUUInstance.isNotEmpty) {
      print("📦 Membuka penyimpanan lokal untuk ${boxUUInstance.length} UU...");
      for (var uu in boxUUInstance.values) {
        await Hive.openBox<PasalModel>('pasal_${uu.id}');
      }
    }
  }

  static Future<bool> checkForUpdates() async {
    try {
      final allLocal = getAllPasal();
      if (allLocal.isEmpty) return true; 

      List<PasalModel> tempSort = List.from(allLocal);
      tempSort.sort((a, b) {
        final tA = a.updatedAt ?? a.createdAt ?? DateTime(2000);
        final tB = b.updatedAt ?? b.createdAt ?? DateTime(2000);
        return tB.compareTo(tA);
      });
      
      final DateTime localLatest = tempSort.first.updatedAt ?? 
                                   tempSort.first.createdAt ?? 
                                   DateTime(2000);

      final response = await supabase
          .from('pasal')
          .select('updated_at, created_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        DateTime serverLatest;
        if (response['updated_at'] != null) {
          serverLatest = DateTime.parse(response['updated_at']);
        } else if (response['created_at'] != null) {
          serverLatest = DateTime.parse(response['created_at']);
        } else {
          return false;
        }

        if (serverLatest.difference(localLatest).inSeconds > 5) {
          print("⚠️ Update tersedia! Beda waktu: ${serverLatest.difference(localLatest).inSeconds} detik");
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> syncData() async {
    try {
      print("🔄 Mulai download data UU...");
      final List<dynamic> responseUU = await supabase
          .from('undang_undang')
          .select()
          .order('tahun', ascending: false);

      print("✅ Ditemukan ${responseUU.length} UU di Server.");

      final boxUUInstance = Hive.box<UndangUndangModel>(boxUU);
      
      for (var item in responseUU) {
        final uu = UndangUndangModel.fromJson(item);
        await boxUUInstance.put(uu.id, uu);
        
        await _syncPasalForUU(uu.id, uu.kode);
      }
      return true;
    } catch (e) {
      print("❌ Sync Error: $e");
      return false;
    }
  }

  static Future<void> _syncPasalForUU(String uuId, String kodeUU) async {
    try {
      final List<dynamic> responsePasal = await supabase
          .from('pasal')
          .select()
          .eq('undang_undang_id', uuId);

      print("   ⬇️ Download $kodeUU: Dapat ${responsePasal.length} pasal.");

      final boxName = 'pasal_$uuId';
      final boxPasal = await Hive.openBox<PasalModel>(boxName);

      for (var item in responsePasal) {
        final pasal = PasalModel.fromJson(item);
        await boxPasal.put(pasal.id, pasal);
      }
    } catch (e) {
      print("❌ Gagal sync pasal $kodeUU: $e");
    }
  }


  static List<UndangUndangModel> getAllUU() {
    if (!Hive.isBoxOpen(boxUU)) return []; 
    final box = Hive.box<UndangUndangModel>(boxUU);
    return box.values.toList();
  }

  static List<PasalModel> getAllPasal() {
    List<PasalModel> allPasals = [];
    if (!Hive.isBoxOpen(boxUU)) return [];

    final boxUUInstance = Hive.box<UndangUndangModel>(boxUU);
    
    for (var uu in boxUUInstance.values) {
      final boxName = 'pasal_${uu.id}';
      if (Hive.isBoxOpen(boxName)) {
        allPasals.addAll(Hive.box<PasalModel>(boxName).values);
      }
    }
    return allPasals;
  }

  static List<PasalModel> searchPasal(String query) {
    if (query.isEmpty) return [];
    final all = getAllPasal();
    return all.where((p) {
      return p.isi.toLowerCase().contains(query.toLowerCase()) ||
             p.nomor.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  static PasalModel? getPasalById(String id) {
    final all = getAllPasal();
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  static String getKodeUU(String uuId) {
    if (!Hive.isBoxOpen(boxUU)) return "UU";
    final box = Hive.box<UndangUndangModel>(boxUU);
    final uu = box.get(uuId);
    return uu?.kode ?? "UU";
  }
  
  static List<PasalModel> getPasalByUU(String uuId) {
    final boxName = 'pasal_$uuId';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<PasalModel>(boxName).values.toList();
    }
    return [];
  }
  
  static List<PasalModel> getPasalByKeyword(String keyword) {
    final all = getAllPasal();
    return all.where((p) => p.isi.toLowerCase().contains(keyword.toLowerCase())).toList();
  }
}