import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArchiveService {
  static final ArchiveService _instance = ArchiveService._internal();
  factory ArchiveService() => _instance;
  ArchiveService._internal() {
    _loadArchives();
  }

  static const String _storageKey = 'archived_pasal_ids';
  
  final ValueNotifier<List<String>> archivedIds = ValueNotifier([]);

  Future<void> _loadArchives() async {
    final prefs = await SharedPreferences.getInstance();
    archivedIds.value = prefs.getStringList(_storageKey) ?? [];
  }

  bool isArchived(String pasalId) {
    return archivedIds.value.contains(pasalId);
  }

  Future<void> toggleArchive(String pasalId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentList = List.from(archivedIds.value);

    if (currentList.contains(pasalId)) {
      currentList.remove(pasalId);
    } else {
      currentList.add(pasalId);
    }

    archivedIds.value = currentList;
    await prefs.setStringList(_storageKey, currentList);
  }
}

final archiveService = ArchiveService();