import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:csv/csv.dart';

class CsvService {
  List<Map<String, dynamic>> parseCsvFromBytes(Uint8List bytes) {
    try {
      // 1. Decodifica e pulizia dal BOM UTF-8
      String csvString = utf8.decode(bytes);
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      // 2. Configurazione del parser
      // Usiamo 'shouldParseNumbers: true' per convertire automaticamente 1000 in numero
      // E proviamo a rilevare il separatore se necessario
      List<List<dynamic>> fields = const CsvToListConverter(
        fieldDelimiter: ',', // Forza la virgola come nel tuo esempio
        eol: '\n',           // Fine riga standard
        shouldParseNumbers: true,
      ).convert(csvString);

      // Rimuove eventuali righe completamente vuote
      fields.removeWhere((row) => row.isEmpty || (row.length == 1 && row[0] == null));

      if (fields.isEmpty) {
        developer.log('Il file CSV sembra vuoto dopo il parsing.');
        return [];
      }

      // 3. Estrazione Header con pulizia spazi
      List<String> headers = fields[0].map((e) => e.toString().trim()).toList();
      developer.log('Header rilevati: $headers');

      List<Map<String, dynamic>> data = [];

      for (var i = 1; i < fields.length; i++) {
        Map<String, dynamic> row = {};
        for (var j = 0; j < headers.length; j++) {
          // Assegna il valore gestendo colonne mancanti nella riga
          var value = j < fields[i].length ? fields[i][j] : "";
          row[headers[j]] = value;
        }
        data.add(row);
      }

      developer.log('Righe elaborate: ${data.length}');
      return data;
    } catch (e) {
      developer.log('Errore critico durante il parsing: $e');
      return [];
    }
  }
}