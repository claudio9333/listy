import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _key = 'saved_csv_files';

  // Salva l'intera lista di file nello storage
  Future<void> saveAllFiles(List<Map<String, dynamic>> files) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(files));
  }

  // Aggiunge un nuovo file con tutti i metadati iniziali, incluso il path fisico
  Future<void> addFile(String name, List<Map<String, dynamic>> data, String? path) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();
    currentFiles.add({
      'name': name,
      'data': data,
      'path': path, 
      'editableColumn': null,
      'visibleColumns': null,
      'columnTypes': <String, String>{},
    });
    await saveAllFiles(currentFiles);
  }

  // Recupera la lista completa di file e relativi metadati
  Future<List<Map<String, dynamic>>> getAllFiles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);
    if (encodedData == null) return [];

    return List<Map<String, dynamic>>.from(jsonDecode(encodedData));
  }

  Future<void> updateFile(int index, String name, List<Map<String, dynamic>> data,
      {String? path, String? editableCol, List<String>? visibleCols, Map<String, String>? colTypes}) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();

    if (index >= 0 && index < currentFiles.length) {
      currentFiles[index] = {
        'name': name,
        'data': data,
        'path': path,
        'editableColumn': editableCol,
        'visibleColumns': visibleCols,
        'columnTypes': colTypes ?? <String, String>{},
      };
      await saveAllFiles(currentFiles);
    }
  }

  Future<void> deleteFile(int index) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();
    if (index >= 0 && index < currentFiles.length) {
      currentFiles.removeAt(index);
      await saveAllFiles(currentFiles);
    }
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}