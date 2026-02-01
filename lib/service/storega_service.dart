import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _key = 'saved_csv_files';

  // Salva l'intera lista di file nello storage
  Future<void> saveAllFiles(List<Map<String, dynamic>> files) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(files));
  }

  // Aggiunge un nuovo file con tutti i metadati iniziali
  Future<void> addFile(String name, List<Map<String, dynamic>> data) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();
    currentFiles.add({
      'name': name,
      'data': data,
      'editableColumn': null, // Inizialmente nessuna colonna è editabile
      'visibleColumns': null, // Tutte le colonne sono visibili di default
      'columnTypes': <String, String>{}, // Mappa dei tipi (testo, numero, ecc.)
    });
    await saveAllFiles(currentFiles);
  }

  // Recupera la lista completa di file e relativi metadati
  Future<List<Map<String, dynamic>>> getAllFiles() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_key);
    if (encodedData == null) return [];

    // Decodifica la stringa JSON in una lista di mappe
    return List<Map<String, dynamic>>.from(jsonDecode(encodedData));
  }

  // Aggiorna un file specifico basandosi sul suo indice nella lista
  // Questa funzione integra la logica di "saveFile" che avevi per il singolo file
  Future<void> updateFile(int index, String name, List<Map<String, dynamic>> data,
      {String? editableCol, List<String>? visibleCols, Map<String, String>? colTypes}) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();

    if (index >= 0 && index < currentFiles.length) {
      currentFiles[index] = {
        'name': name,
        'data': data, // Include i dati modificati nei textbox
        'editableColumn': editableCol,
        'visibleColumns': visibleCols,
        'columnTypes': colTypes ?? <String, String>{},
      };
      await saveAllFiles(currentFiles);
    }
  }

  // Rimuove un file specifico
  Future<void> deleteFile(int index) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();
    if (index >= 0 && index < currentFiles.length) {
      currentFiles.removeAt(index);
      await saveAllFiles(currentFiles);
    }
  }

  // Pulisce tutto il database locale
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> addNewRow(int fileIndex) async {
    final List<Map<String, dynamic>> allFiles = await getAllFiles();
    if (fileIndex >= 0 && fileIndex < allFiles.length) {
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(allFiles[fileIndex]['data']);

      // Crea una nuova riga con chiavi vuote basate sulle colonne esistenti
      if (data.isNotEmpty) {
        final Map<String, dynamic> newRow = {
          for (var key in data.first.keys) key: ""
        };
        data.add(newRow);

        // Aggiorna il file nella lista
        allFiles[fileIndex]['data'] = data;
        await saveAllFiles(allFiles);
      }
    }
  }
}