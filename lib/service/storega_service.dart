import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _key = 'saved_csv_files';

  // Salva l'intera lista di file nello storage
  Future<void> saveAllFiles(List<Map<String, dynamic>> files) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(files));
  }

  // Aggiunge un nuovo file con tutti i metadati, inclusi i delimitatori e il contenuto grezzo
  Future<void> addFile(
      String name,
      List<Map<String, dynamic>> data, {
        String? path,
        String? rawContent,
        String fieldDelimiter = ',',
        String eol = '\n'
      }) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();
    currentFiles.add({
      'name': name,
      'data': data,
      'path': path,
      'rawContent': rawContent,
      'fieldDelimiter': fieldDelimiter,
      'eol': eol,
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

  // Metodo aggiornato per gestire tutti i metadati durante l'update
  Future<void> updateFile(int index, String name, List<Map<String, dynamic>> data,
      {String? path,
        String? rawContent,
        String? fieldDelimiter,
        String? eol,
        String? editableCol,
        List<String>? visibleCols,
        Map<String, String>? colTypes}) async {
    final List<Map<String, dynamic>> currentFiles = await getAllFiles();

    if (index >= 0 && index < currentFiles.length) {
      currentFiles[index] = {
        'name': name,
        'data': data,
        'path': path ?? currentFiles[index]['path'],
        'rawContent': rawContent ?? currentFiles[index]['rawContent'],
        'fieldDelimiter': fieldDelimiter ?? currentFiles[index]['fieldDelimiter'],
        'eol': eol ?? currentFiles[index]['eol'],
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

  Future<dynamic> loadCsv(String? path) async {
    // All'interno della tua classe StorageServiceFuture<List<Map<String, dynamic>>> loadCsv(String path) async {
    try {
      final file = File(path!);

      // 1. Controlla se il file esiste
      if (!await file.exists()) {
        return [];
      }

      // 2. Leggi il contenuto del file
      final String csvContent = await file.readAsString();

      // 3. Trasforma il contenuto in righe (gestendo i ritorni a capo)
      // Se usi la libreria 'csv', puoi usare:
      // List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);
      // Altrimenti, un'implementazione manuale semplice (senza virgole nei campi):
      final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.isEmpty) return [];

      // 4. Estrai l'header (la prima riga)
      final headers = lines[0].split(',');

      // 5. Mappa ogni riga successiva in una Map<String, dynamic>
      final List<Map<String, dynamic>> data = [];
      for (int i = 1; i < lines.length; i++) {
        final values = lines[i].split(',');
        final Map<String, dynamic> row = {};

        for (int j = 0; j < headers.length; j++) {
          // Gestisci il caso in cui una riga abbia meno colonne dell'header
          row[headers[j].trim()] = j < values.length ? values[j].trim() : "";
        }
        data.add(row);
      }

      return data;
    } catch (e) {
      print("Errore nel caricamento del file CSV: $e");
      rethrow; // Rilancia l'errore per gestirlo nella UI
    }
  }
}