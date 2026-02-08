import 'dart:io';
import 'package:flutter/material.dart';
import '../service/csv_service.dart';

class CsvDetailPage extends StatefulWidget {
  final Map<String, dynamic> record;
  final List<String> allColumns;
  final String fileName;
  final String? path;
  final int fileIndex;
  final dynamic storageService;

  const CsvDetailPage({
    super.key,
    required this.record,
    required this.allColumns,
    required this.fileName,
    this.path,
    required this.fileIndex,
    required this.storageService,
  });

  @override
  State<CsvDetailPage> createState() => _CsvDetailPageState();
}

class _CsvDetailPageState extends State<CsvDetailPage> {
  bool _isEditing = false;
  late Map<String, TextEditingController> _controllers;
  final CsvService _csvService = CsvService();

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var col in widget.allColumns)
        col: TextEditingController(text: widget.record[col]?.toString() ?? "")
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _deleteRecord() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina record"),
        content: const Text("Sei sicuro di voler eliminare definitivamente questo record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Elimina", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final List<Map<String, dynamic>> allFiles = await widget.storageService.getAllFiles();

      if (widget.fileIndex >= 0 && widget.fileIndex < allFiles.length) {
        List<dynamic> data = List.from(allFiles[widget.fileIndex]['data']);
        int indexInFileData = data.indexWhere((item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          return widget.allColumns.every((col) {
            return row[col]?.toString() == widget.record[col]?.toString();
          });
        });

        if (indexInFileData != -1) {
          data.removeAt(indexInFileData);
          allFiles[widget.fileIndex]['data'] = data;
          await widget.storageService.saveAllFiles(allFiles);
          if (widget.path != null && widget.path!.isNotEmpty) {
            try {
              final String csvString = _csvService.mapToCsv(
                  data.map((e) => Map<String, dynamic>.from(e)).toList(),
                  widget.allColumns
              );
              final File file = File(widget.path!);
              await file.writeAsString(csvString);
              debugPrint("File fisico aggiornato con successo");
            } catch (e) {
              debugPrint("Impossibile aggiornare il file fisico: $e");
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Record eliminato con successo")),
            );
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      debugPrint("Errore durante l'eliminazione: $e");
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      for (var col in widget.allColumns) {
        widget.record[col] = _controllers[col]!.text;
      }
      _isEditing = false;
    });

    try {
      final List<Map<String, dynamic>> allFiles = await widget.storageService.getAllFiles();
      if (widget.fileIndex >= 0 && widget.fileIndex < allFiles.length) {
        final List<dynamic> data = allFiles[widget.fileIndex]['data'];
        final int index = data.indexOf(widget.record);

        if (index != -1) {
          data[index] = widget.record;
          await widget.storageService.saveAllFiles(allFiles);
        }
      }

      if (widget.path != null && widget.path!.isNotEmpty) {
        final List<Map<String, dynamic>> currentFileData =
        List<Map<String, dynamic>>.from(allFiles[widget.fileIndex]['data']);
        final String csvString = _csvService.mapToCsv(currentFileData, widget.allColumns);
        final File file = File(widget.path!);
        await file.writeAsString(csvString);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modifiche salvate con successo")),
        );
      }
    } catch (e) {
      debugPrint("Errore durante il salvataggio: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dettaglio Record"),
        centerTitle: true,
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: "Elimina record",
              onPressed: _deleteRecord,
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: "Modifica",
              onPressed: () => setState(() => _isEditing = true),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: "Salva",
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: widget.allColumns.map((col) {
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    col.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      controller: _controllers[col],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    Text(
                      widget.record[col]?.toString() ?? "N/A",
                      style: theme.textTheme.bodyLarge,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
