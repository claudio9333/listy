import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

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
      final path = result.files.single.path;
      final bytes = result.files.single.bytes!;
      final parsedData = _csvService.parseCsvFromBytes(bytes);

      await _storageService.addFile(name, parsedData, path);
      _refreshData();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Le mie liste")),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allFiles.isEmpty
          ? const Center(child: Text("Nessun file caricato. Clicca +"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allFiles.length,
        itemBuilder: (context, index) {
          final fileMap = _allFiles[index];
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(Symbols.csv,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40),
              title: Text(fileMap['name'], style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              )),
              subtitle: Text("${(fileMap['data'] as List).length} righe"),
              trailing: IconButton(
                icon: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.secondary),
                onPressed: () async {
                  await _storageService.deleteFile(index);
                  _refreshData();
                },
              ),
              onTap: () async {
                final List<Map<String, dynamic>> allFiles = await _storageService.getAllFiles();
                final fileMap = allFiles[index];
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CsvViewPage(
                      fileName: fileMap['name'],
                      path: fileMap['path'],
                      data: List<Map<String, dynamic>>.from(fileMap['data']),
                      initialEditableColumn: fileMap['editableColumn'],
                      initialVisibleColumns: fileMap['visibleColumns'] != null
                          ? List<String>.from(fileMap['visibleColumns'])
                          : null,
                      initialColumnTypes: fileMap['columnTypes'] != null
                          ? Map<String, String>.from(fileMap['columnTypes'])
                          : {},
                      storageService: _storageService,
                      fileIndex: index,
                    ),
                  ),
                );

                // 2. Quando l'utente torna indietro, aggiorna la lista dei file
                _refreshData();
                            },
            ),
          );
        },
      ),
    );
  }
}