import 'package:flutter/material.dart';
import '../service/csv_service.dart';

class FileSettingsPage extends StatefulWidget {
  final String currentName;
  final int fileIndex;
  final dynamic storageService;

  const FileSettingsPage({
    super.key,
    required this.currentName,
    required this.fileIndex,
    required this.storageService,
  });

  @override
  State<FileSettingsPage> createState() => _FileSettingsPageState();
}

class _FileSettingsPageState extends State<FileSettingsPage> {
  late TextEditingController _nameController;
  late String _fieldDelimiter;
  late String _eol;
  final CsvService _csvService = CsvService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _fieldDelimiter = ',';
    _eol = '\n';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final allFiles = await widget.storageService.getAllFiles();
    if (widget.fileIndex < allFiles.length) {
      final fileData = allFiles[widget.fileIndex];
      setState(() {
        _fieldDelimiter = fileData['fieldDelimiter'] ?? ',';
        _eol = fileData['eol'] ?? '\n';
      });
    }
  }

  Future<void> _saveChanges() async {
    final allFiles = await widget.storageService.getAllFiles();
    if (widget.fileIndex < allFiles.length) {
      final fileMap = allFiles[widget.fileIndex];

      fileMap['name'] = _nameController.text;

      bool dataRecreated = false;
      // Se i delimitatori sono cambiati, ricreiamo i dati dal contenuto grezzo
      final String? raw = fileMap['rawContent'];
      if (raw != null) {
          // Ri-parsing dei dati con le nuove impostazioni
          final newData = _csvService.parseCsvFromString(
              raw,
              fieldDelimiter: _fieldDelimiter,
              eol: _eol
          );
          fileMap['data'] = newData;
          fileMap['visibleColumns'] = null;
          fileMap['columnTypes'] = {};
          fileMap['editableColumn'] = null;
          dataRecreated = true;
        }
      fileMap['fieldDelimiter'] = _fieldDelimiter;
      fileMap['eol'] = _eol;

      await widget.storageService.saveAllFiles(allFiles);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impostazioni salvate con successo")),
        );
        Navigator.pop(context, {
          'newName': _nameController.text,
          'reloaded': dataRecreated,
          'data': fileMap['data']
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text("Elimina File"),
        content: const Text(
            "Sei sicuro di voler eliminare definitivamente questo file? Questa azione non è reversibile."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Elimina"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.deleteFile(widget.fileIndex);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Impostazioni File"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Sezione Generale
          Text(
            "Generale",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Nome del file",
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sezione Formato CSV
          Text(
            "Formato CSV",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _fieldDelimiter,
                    decoration: InputDecoration(
                      labelText: "Delimitatore di campo",
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: ',', child: Text("Virgola ( , )")),
                      DropdownMenuItem(value: ';', child: Text("Punto e virgola ( ; )")),
                      DropdownMenuItem(value: '\t', child: Text("Tabulazione ( Tab )")),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _fieldDelimiter = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _eol,
                    decoration: InputDecoration(
                      labelText: "Fine riga (EOL)",
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: '\n', child: Text("LF ( \\n ) - Linux/macOS")),
                      DropdownMenuItem(value: '\r\n', child: Text("CRLF ( \\r\\n ) - Windows")),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _eol = value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check_rounded),
              label: const Text("Salva tutte le modifiche"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Sezione Zona Pericolosa
          Text(
            "Zona Pericolosa",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: colorScheme.errorContainer.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.error.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "L'eliminazione è permanente e non può essere annullata.",
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text("Elimina definitivamente"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
