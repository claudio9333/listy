import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:csv/csv.dart';

class CsvService {
  List<Map<String, dynamic>> parseCsvFromBytes(Uint8List bytes, {String fieldDelimiter = ',', String eol = '\n'}) {
    try {
      String csvString = utf8.decode(bytes);
      return parseCsvFromString(csvString, fieldDelimiter: fieldDelimiter, eol: eol);
    } catch (e) {
      developer.log('Errore durante la decodifica dei bytes: $e');
      return [];
    }
  }

  List<Map<String, dynamic>> parseCsvFromString(String csvString, {String fieldDelimiter = ',', String eol = '\n'}) {
    try {
      if (csvString.startsWith('\uFEFF')) {
        csvString = csvString.substring(1);
      }

      List<List<dynamic>> fields = CsvToListConverter(
        fieldDelimiter: fieldDelimiter,
        eol: eol,
        shouldParseNumbers: true,
      ).convert(csvString);

      fields.removeWhere((row) => row.isEmpty || (row.length == 1 && row[0] == null));

      if (fields.isEmpty) {
        developer.log('Il file CSV sembra vuoto dopo il parsing.');
        return [];
      }

      List<String> headers = fields[0].map((e) => e.toString().trim()).toList();
      developer.log('Header rilevati: $headers');

      List<Map<String, dynamic>> data = [];

      for (var i = 1; i < fields.length; i++) {
        Map<String, dynamic> row = {};
        for (var j = 0; j < headers.length; j++) {
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

  String mapToCsv(List<Map<String, dynamic>> data, List<String> headers, {String fieldDelimiter = ',', String eol = '\n'}) {
    try {
      List<List<dynamic>> rows = [];
      rows.add(headers);
      for (var map in data) {
        List<dynamic> row = headers.map((header) => map[header]).toList();
        rows.add(row);
      }
      return ListToCsvConverter(
        fieldDelimiter: fieldDelimiter,
        eol: eol,
      ).convert(rows);
    } catch (e) {
      developer.log('Errore durante la generazione del CSV: $e');
      return "";
    }
  }
}