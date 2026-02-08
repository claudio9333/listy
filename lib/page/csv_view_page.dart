import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../service/csv_service.dart';
import '../service/pdf_service.dart';
import 'csv_detalis_page.dart';
import 'file_settings_page.dart';
import 'package:flutter/foundation.dart';

class CsvViewPage extends StatefulWidget {
  final String fileName;
  final String? path;
  final List<Map<String, dynamic>> data;
  final String? initialEditableColumn;
  final List<String>? initialVisibleColumns;
  final Map<String, String>? initialColumnTypes;
  final dynamic storageService;
  final int fileIndex;

  const CsvViewPage({
    super.key,
    required this.fileName,
    this.path,
    required this.data,
    this.initialEditableColumn,
    this.initialVisibleColumns,
    this.initialColumnTypes,
    required this.storageService,
    required this.fileIndex,
  });

  @override
  State<CsvViewPage> createState() => _CsvPageState();
}

class _CsvPageState extends State<CsvViewPage> {
  late List<Map<String, dynamic>> _currentData;
  late List<String> _allColumns;
  late Set<String> _visibleColumns;
  late Map<String, String> _columnTypes;
  String? _editableColumn;
  final Set<int> _selectedRows = {};
  final PdfService _pdfService = PdfService();
  final CsvService _csvService = CsvService();

  bool get _isSelectionMode => _selectedRows.isNotEmpty;
  late String _currentFileName;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchColumn = "";
  int _resetCounter = 0;

  @override
  void initState() {
    super.initState();
    _currentFileName = widget.fileName;
    _currentData = List.from(widget.data);
    _editableColumn = widget.initialEditableColumn;
    _columnTypes = widget.initialColumnTypes ?? {};

    if (widget.data.isNotEmpty) {
      _allColumns = widget.data.first.keys.toList();
      _visibleColumns = widget.initialVisibleColumns != null
          ? Set.from(widget.initialVisibleColumns!)
          : Set.from(_allColumns);

      _searchColumn = _visibleColumns.first;

      for (var col in _allColumns) {
        _columnTypes.putIfAbsent(col, () => 'off');
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _currentData = List.from(widget.data);
      } else {
        _currentData = widget.data.where((row) {
          final cellValue = row[_searchColumn]?.toString().toLowerCase() ?? "";
          return cellValue.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _autoSave() async {
    try {
      final List<Map<String, dynamic>> allFiles = await widget.storageService.getAllFiles();
      if (widget.fileIndex >= 0 && widget.fileIndex < allFiles.length) {
        allFiles[widget.fileIndex] = {
          'name': _currentFileName,
          'data': widget.data,
          'path': widget.path,
          'editableColumn': _editableColumn,
          'visibleColumns': _visibleColumns.toList(),
          'columnTypes': _columnTypes,
        };
        await widget.storageService.saveAllFiles(allFiles);
      }
    } catch (e) {
      debugPrint("Errore SharedPreferences: $e");
    }

    if (!kIsWeb && widget.path != null && widget.path!.isNotEmpty) {
      if (widget.path!.startsWith('/') || widget.path!.contains(':')) {
        try {
          final String csvString = _csvService.mapToCsv(widget.data, _allColumns);
          final File file = File(widget.path!);
          await file.writeAsString(csvString);
        } catch (e) {
          debugPrint("Salvataggio fisico non riuscito: $e");
        }
      }
    }
  }

  void _updateEditableType(String col, String type) {
    setState(() {
      if (type == 'off') {
        _columnTypes[col] = 'off';
        if (_editableColumn == col) _editableColumn = null;
      } else {
        _columnTypes.updateAll((key, value) => 'off');
        _columnTypes[col] = type;
        _editableColumn = col;
      }
    });
    _autoSave();
  }

  void _clearEditableColumn() {
    if (_editableColumn == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Pulisci colonna"),
        content: Text("Vuoi cancellare tutti i valori nella colonna '$_editableColumn'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          FilledButton(
            onPressed: () {
              setState(() {
                for (var row in widget.data) {
                  row[_editableColumn!] = "";
                }
                _resetCounter++;
                if (_isSearching) {
                  _performSearch(_searchController.text);
                } else {
                  _currentData = List.from(widget.data);
                }
              });
              _autoSave();
              Navigator.pop(context);
            },
            child: const Text("Pulisci tutto"),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePdfExport() async {
    final visibleColumnsList = _allColumns.where((col) => _visibleColumns.contains(col)).toList();
    final filteredData = widget.data.where((row) {
      if (_editableColumn == null) return true;
      final value = row[_editableColumn];
      if (value == null) return false;
      final String strValue = value.toString().trim();
      return strValue != "" && strValue != "0" && strValue != "0.0";
    }).toList();

    await _pdfService.generateAndPrintPdf(
      _currentFileName,
      visibleColumnsList,
      filteredData,
    );
  }

  Future<void> _exportUpdatedCsv() async {
    final String csvString = _csvService.mapToCsv(widget.data, _allColumns);
    if (csvString.isEmpty) return;
    try {
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/$_currentFileName.csv";
      final file = File(path);
      await file.writeAsString(csvString);
      await Share.shareXFiles([XFile(path)], text: 'Esporta CSV aggiornato');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Da implementare...")),
        );
        developer.log("Errore durante l'esportazione: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayColumns = _allColumns.where((col) => _visibleColumns.contains(col)).toList();

    if (!_visibleColumns.contains(_searchColumn) && displayColumns.isNotEmpty) {
      _searchColumn = displayColumns.first;
    }

    return PopScope(
      canPop: !_isSearching && !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            _currentData = List.from(widget.data);
          });
        } else if (_isSelectionMode) {
          setState(() => _selectedRows.clear());
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        // Menu laterale con tutte le azioni
        drawer: _buildDrawer(theme, colorScheme),
        appBar: AppBar(
          automaticallyImplyLeading: !_isSearching, // Nasconde l'hamburger durante la ricerca
          scrolledUnderElevation: 4,
          toolbarHeight: _isSearching ? 80 : 64,
          backgroundColor: _isSelectionMode ? colorScheme.primaryContainer : null,
          title: _isSelectionMode
              ? Text("${_selectedRows.length} selezionati")
              : (_isSearching
              ? _buildModernSearchField(colorScheme, displayColumns)
              : Text(_currentFileName)),
          actions: [
            if (_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: _deleteSelectedRows,
              )
            else ...[
              IconButton(
                icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
                onPressed: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _currentData = List.from(widget.data);
                  }
                }),
              ),
              if (_editableColumn != null && !_isSearching)
                IconButton(
                  tooltip: "Pulisci colonna '$_editableColumn'",
                  icon: const Icon(FontAwesomeIcons.eraser, size: 20),
                  onPressed: _clearEditableColumn,
                ),
            ]
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: displayColumns.length * 200.0,
                  child: Column(
                    children: [
                      _buildHeader(displayColumns, colorScheme, theme),
                      Expanded(
                        child: _currentData.isEmpty
                            ? _buildEmptyState(colorScheme)
                            : ListView.separated(
                          itemCount: _currentData.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final realIndex = widget.data.indexOf(_currentData[index]);
                            final isSelected = _selectedRows.contains(realIndex);

                            return InkWell(
                              onLongPress: () => _toggleSelection(index),
                              onTap: _isSelectionMode
                                  ? () => _toggleSelection(index)
                                  : () async {
                                // Aspettiamo il risultato dal Navigator. Se è 'true', il record è stato eliminato.
                                final bool? result = await Navigator.push<bool>(
                                  context,MaterialPageRoute(
                                  builder: (_) => CsvDetailPage(
                                    record: _currentData[index],
                                    allColumns: _allColumns,
                                    fileName: _currentFileName,
                                    path: widget.path,
                                    fileIndex: widget.fileIndex,
                                    storageService: widget.storageService,
                                  ),
                                ),
                                );

                                if (result == true && mounted) {
                                  // Se il record è stato eliminato, lo rimuoviamo dalle liste locali e aggiorniamo la UI
                                  setState(() {
                                    final recordToRemove = _currentData[index];
                                    widget.data.remove(recordToRemove); // Rimuove dalla lista completa
                                    _currentData.removeAt(index);       // Rimuove dalla vista attuale (anche se filtrata)
                                  });
                                } else {
                                  // Se è stato solo modificato o semplicemente chiuso, rinfreschiamo comunque la UI
                                  setState(() {});
                                }
                              },
                              child: Container(
                                color: isSelected ? colorScheme.primary.withValues(alpha: 0.12) : null,
                                child: _buildRow(index, displayColumns, theme, colorScheme),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _isSelectionMode
            ? null
            : FloatingActionButton.extended(
          onPressed: _addNewRecord,
          icon: const Icon(Icons.add_rounded),
          label: const Text("Nuovo Record"),
        ),
      ),
    );
  }

  // Costruzione del Menu Laterale (Drawer)
  Widget _buildDrawer(ThemeData theme, ColorScheme colorScheme) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primaryContainer),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FontAwesomeIcons.fileCsv, size: 40, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    _currentFileName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text("Esporta PDF"),
            onTap: () {
              Navigator.pop(context);
              _handlePdfExport();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download_rounded),
            title: const Text("Scarica CSV"),
            onTap: () {
              Navigator.pop(context);
              _exportUpdatedCsv();
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text("Configura colonne"),
            onTap: () {
              Navigator.pop(context);
              _showSettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text("Impostazioni file"),
            onTap: () async {
              Navigator.pop(context);
              final newName = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => FileSettingsPage(
                    currentName: _currentFileName,
                    fileIndex: widget.fileIndex,
                    storageService: widget.storageService,
                  ),
                ),
              );
              if (newName != null && mounted) {
                setState(() => _currentFileName = newName);
                _autoSave();
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildModernSearchField(ColorScheme colorScheme, List<String> displayColumns) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          DropdownButton<String>(
            value: _searchColumn,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            items: displayColumns
                .map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() {
              _searchColumn = v!;
              _performSearch(_searchController.text);
            }),
          ),
          const VerticalDivider(indent: 12, endIndent: 12, width: 24),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                hintText: "Cerca in questa colonna...",
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: _performSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<String> columns, ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 48, 16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: columns
            .map((col) => Expanded(
          child: Text(
            col.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildRow(int index, List<String> columns, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ...columns.map((col) {
            final cellValue = _currentData[index][col]?.toString() ?? "";
            if (col == _editableColumn && _columnTypes[col] != 'off') {
              return Container(
                width: 200,
                padding: const EdgeInsets.only(right: 12),
                child: TextFormField(
                  key: ValueKey("row_${index}_${col}_${cellValue}_$_resetCounter"),
                  initialValue: cellValue,
                  keyboardType: _columnTypes[col] == 'int'
                      ? TextInputType.number
                      : _columnTypes[col] == 'double'
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary)),
                  ),
                  onChanged: (v) {
                    _currentData[index][col] = v;
                    _autoSave();
                  },
                ),
              );
            }
            return Expanded(
              child: Text(
                cellValue,
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.8)),
              ),
            );
          }).toList(),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text("Nessun dato corrispondente", style: TextStyle(color: colorScheme.outline)),
        ],
      ),
    );
  }

  void _showSettings() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Text("Configurazione colonne", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ..._allColumns.map((col) {
                final isVisible = _visibleColumns.contains(col);
                final isCurrentlyEditable = _editableColumn == col;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: !isVisible
                      ? ListTile(
                    leading: Checkbox(
                        value: false,
                        onChanged: (v) {
                          setState(() => _visibleColumns.add(col));
                          setST(() {});
                          _autoSave();
                        }),
                    title: Text(col, style: TextStyle(color: theme.disabledColor)),
                  )
                      : ExpansionTile(
                    key: Key(col + (isCurrentlyEditable ? '_open' : '_closed')),
                    initiallyExpanded: isCurrentlyEditable,
                    leading: Checkbox(
                        value: true,
                        onChanged: (v) {
                          setState(() {
                            _visibleColumns.remove(col);
                            if (_editableColumn == col) {
                              _editableColumn = null;
                              _columnTypes[col] = 'off';
                            }
                          });
                          setST(() {});
                          _autoSave();
                        }),
                    title: Text(col),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'off', label: Text("Off"), icon: Icon(Icons.edit_off)),
                            ButtonSegment(value: 'text', label: Text("Abc"), icon: Icon(Icons.abc)),
                            ButtonSegment(value: 'int', label: Text("123"), icon: Icon(Icons.tag)),
                            ButtonSegment(value: 'double', label: Text("1.1"), icon: Icon(Icons.pin_outlined)),
                          ],
                          selected: {_columnTypes[col]!},
                          onSelectionChanged: (newVal) {
                            _updateEditableType(col, newVal.first);
                            setST(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewRecord() {
    final Map<String, dynamic> newRowData = {for (var col in _allColumns) col: ""};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nuovo Record"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _allColumns.map((col) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TextFormField(
                decoration: InputDecoration(labelText: col.toUpperCase(), border: const OutlineInputBorder()),
                onChanged: (value) => newRowData[col] = value,
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          FilledButton(
            onPressed: () {
              setState(() {
                widget.data.insert(0, Map<String, dynamic>.from(newRowData));
                _currentData = List.from(widget.data);
              });
              _autoSave();
              Navigator.pop(context);
            },
            child: const Text("Aggiungi"),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int indexInCurrent) {
    final realIndex = widget.data.indexOf(_currentData[indexInCurrent]);
    setState(() {
      if (_selectedRows.contains(realIndex)) {
        _selectedRows.remove(realIndex);
      } else {
        _selectedRows.add(realIndex);
      }
    });
  }

  void _deleteSelectedRows() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina record"),
        content: Text("Vuoi eliminare ${_selectedRows.length} record selezionati?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          FilledButton(
            onPressed: () {
              setState(() {
                final sortedIndices = _selectedRows.toList()..sort((a, b) => b.compareTo(a));
                for (var index in sortedIndices) {
                  widget.data.removeAt(index);
                }
                _selectedRows.clear();
                _currentData = List.from(widget.data);
              });
              _autoSave();
              Navigator.pop(context);
            },
            child: const Text("Elimina"),
          ),
        ],
      ),
    );
  }
}
