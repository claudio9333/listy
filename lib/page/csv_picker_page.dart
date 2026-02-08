import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../service/csv_service.dart';
import '../service/storega_service.dart';
import 'csv_view_page.dart';

class CsvPickerScreen extends StatefulWidget {
  const CsvPickerScreen({super.key});

  @override
  _CsvPickerScreenState createState() => _CsvPickerScreenState();
}

class _CsvPickerScreenState extends State<CsvPickerScreen> {
  List<Map<String, dynamic>> _allFiles = [];
  bool _isLoading = false;

  final CsvService _csvService = CsvService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() async {
    final files = await _storageService.getAllFiles();
    setState(() {
      _allFiles = files;
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null) {
      setState(() => _isLoading = true);

      final name = result.files.single.name;
      final bytes = result.files.single.bytes!;
      final rawContent = utf8.decode(bytes);
      final parsedData = _csvService.parseCsvFromBytes(bytes);
      await _storageService.addFile(
        name,
        parsedData,
        rawContent: rawContent,
        fieldDelimiter: ',',
        eol: '\n',
      );

      setState(() => _isLoading = false);
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Le mie liste")),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _pickFile,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allFiles.isEmpty
          ? const Center(child: Text("Nessun file caricato. Clicca +"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allFiles.length,
        itemBuilder: (context, index) {
          final file = _allFiles[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(file['name'] ?? "Senza nome"),
              subtitle: Text("${(file['data'] as List).length} righe"),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await _storageService.deleteFile(index);
                  _refreshData();
                },
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CsvViewPage(
                      fileName: file['name'],
                      data: List<Map<String, dynamic>>.from(file['data']),
                      initialEditableColumn: file['editableColumn'],
                      initialVisibleColumns: file['visibleColumns'] != null
                          ? List<String>.from(file['visibleColumns'])
                          : null,
                      initialColumnTypes: file['columnTypes'] != null
                          ? Map<String, String>.from(file['columnTypes'])
                          : {},
                      storageService: _storageService,
                      fileIndex: index,
                    ),
                  ),
                );
                _refreshData();
              },
            ),
          );
        },
      ),
    );
  }
}