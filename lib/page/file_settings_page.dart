import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  Future<void> _renameFile() async {
    final allFiles = await widget.storageService.getAllFiles();
    if (widget.fileIndex < allFiles.length) {
      allFiles[widget.fileIndex]['name'] = _nameController.text;
      await widget.storageService.saveAllFiles(allFiles);
      if (mounted) Navigator.pop(context, _nameController.text);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina File"),
        content: const Text("Sei sicuro di voler eliminare definitivamente questo file?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annulla")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Elimina"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.deleteFile(widget.fileIndex);
      if (mounted) {
        // Torna alla home e chiude anche la visualizzazione del file
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Impostazioni File")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Nome del file",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _renameFile,
            icon: const Icon(Icons.save_rounded),
            label: const Text("Rinomina File"),
          ),
          const Divider(height: 64),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text("Elimina permanentemente"),
          ),
        ],
      ),
    );
  }
}