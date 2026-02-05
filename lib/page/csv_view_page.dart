import 'package:flutter/material.dart';
import 'csv_detalis_page.dart';
import 'file_settings_page.dart';

class CsvViewPage extends StatefulWidget {
  final String fileName;
  final List<Map<String, dynamic>> data;
  final String? initialEditableColumn;
  final List<String>? initialVisibleColumns;
  final Map<String, String>? initialColumnTypes;
  final dynamic storageService;
  final int fileIndex;

  const CsvViewPage({
    super.key,
    required this.fileName,
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

  bool get _isSelectionMode => _selectedRows.isNotEmpty;
  late String _currentFileName;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchColumn = "";

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

      // Imposta la colonna di ricerca iniziale sulla prima visibile
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
    // 1. Recupera la lista completa di tutti i file dallo storage
    final List<Map<String, dynamic>> allFiles = await widget.storageService
        .getAllFiles();

    // 2. Verifica che l'indice sia valido e aggiorna solo quel file
    if (widget.fileIndex < allFiles.length) {
      allFiles[widget.fileIndex] = {
        'name': widget.fileName,
        'data': _currentData,
        // Salva i dati correnti, inclusi quelli nei textbox [cite: 2026-02-01]
        'editableColumn': _editableColumn,
        'visibleColumns': _visibleColumns.toList(),
        'columnTypes': _columnTypes,
      };

      // 3. Sovrascrivi la lista completa con i nuovi dati
      await widget.storageService.saveAllFiles(allFiles);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayColumns = _allColumns
        .where((col) => _visibleColumns.contains(col))
        .toList();

    // Se la colonna di ricerca selezionata viene nascosta, resetta alla prima visibile
    if (!_visibleColumns.contains(_searchColumn) && displayColumns.isNotEmpty) {
      _searchColumn = displayColumns.first;
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        scrolledUnderElevation: 4,
        toolbarHeight: _isSearching ? 80 : 64,
        backgroundColor: _isSelectionMode ? colorScheme.primaryContainer : null,
        automaticallyImplyLeading: !_isSearching,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedRows.clear()),
              )
            : null,
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
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
              ),
              onPressed: () => setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _currentData = List.from(widget.data);
                }
              }),
            ),
            if (!_isSearching) ...[
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _showSettings,
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () async {
                  final newName = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FileSettingsPage(
                        currentName: widget.fileName,
                        fileIndex: widget.fileIndex,
                        storageService: widget.storageService,
                      ),
                    ),
                  );
                  // Se il nome è stato cambiato, aggiorna la UI
                  if (newName != null && mounted) {
                    setState(() {
                      _currentFileName = newName;
                    });
                  }
                },
              ),
            ],
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                // Definiamo una larghezza minima per forzare lo scroll
                // (es. 200 pixel per ogni colonna visibile)
                width: displayColumns.length * 200.0,
                child: Column(
                  children: [
                    _buildHeader(displayColumns, colorScheme, theme),
                    Expanded(
                      child: _currentData.isEmpty
                          ? _buildEmptyState(colorScheme)
                          : ListView.separated(
                              itemCount: _currentData.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final realIndex = widget.data.indexOf(
                                  _currentData[index],
                                );
                                final isSelected = _selectedRows.contains(
                                  realIndex,
                                );

                                return InkWell(
                                  onLongPress: () => _toggleSelection(index),
                                  onTap: _isSelectionMode
                                      ? () => _toggleSelection(index)
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CsvDetailPage(
                                              record: _currentData[index],
                                              allColumns: _allColumns,
                                            ),
                                          ),
                                        ),
                                  child: Container(
                                    color: isSelected
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.12,
                                          )
                                        : null,
                                    child: _buildRow(
                                      index,
                                      displayColumns,
                                      theme,
                                      colorScheme,
                                    ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                .map(
                  (c) =>
                      DropdownMenuItem(value: c, child: Text(c.toUpperCase())),
                )
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
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: columns
            .map(
              (col) => Expanded(
                child: Text(
                  col.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRow(
    int index,
    List<String> columns,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ...columns.map((col) {
            final value = _currentData[index][col]?.toString() ?? "";
            if (col == _editableColumn && _columnTypes[col] != 'off') {
              return Container(
                width: 200,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextFormField(
                    initialValue: value,
                    keyboardType: _columnTypes[col] == 'int'
                        ? TextInputType.number
                        : _columnTypes[col] == 'double'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    key: Key("row_${index}_$col"),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colorScheme.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      _currentData[index][col] = v;
                      _autoSave();
                    },
                  ),
                ),
              );
            }
            return Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            );
          }).toList(),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: colorScheme.outlineVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "Nessun dato corrispondente",
            style: TextStyle(color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                "Configurazione colonne",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                            },
                          ),
                          title: Text(
                            col,
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        )
                      : ExpansionTile(
                          key: Key(
                            col + (isCurrentlyEditable ? '_open' : '_closed'),
                          ),
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
                            },
                          ),
                          title: Text(col),
                          trailing: isCurrentlyEditable
                              ? Icon(
                                  Icons.edit_note,
                                  color: theme.colorScheme.primary,
                                )
                              : const Icon(Icons.expand_more),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Tipo di input da tastiera",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                        value: 'off',
                                        label: Text("Disabilitato"),
                                        icon: Icon(Icons.edit_off_sharp),
                                      ),
                                      ButtonSegment(
                                        value: 'text',
                                        label: Text("Abc"),
                                        icon: Icon(Icons.abc),
                                      ),
                                      ButtonSegment(
                                        value: 'int',
                                        label: Text("123"),
                                        icon: Icon(Icons.tag),
                                      ),
                                      ButtonSegment(
                                        value: 'double',
                                        label: Text("1.1"),
                                        icon: Icon(Icons.pin_outlined),
                                      ),
                                    ],
                                    selected: {_columnTypes[col]!},
                                    onSelectionChanged: (newVal) {
                                      _updateEditableType(col, newVal.first);
                                      setST(() {});
                                    },
                                  ),
                                ],
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
    // Prepariamo una mappa per contenere i nuovi dati
    final Map<String, dynamic> newRowData = {
      for (var col in _allColumns) col: "",
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aggiungi Nuovo Record"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _allColumns.map((col) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: col.toUpperCase(),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  // Seleziona il tipo di tastiera in base alla tua configurazione colonne
                  keyboardType: _columnTypes[col] == 'int'
                      ? TextInputType.number
                      : _columnTypes[col] == 'double'
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  onChanged: (value) => newRowData[col] = value,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                // Inserisce il nuovo record in cima alla lista
                widget.data.insert(0, Map<String, dynamic>.from(newRowData));

                if (_isSearching) {
                  _performSearch(_searchController.text);
                } else {
                  _currentData = List.from(widget.data);
                }
              });

              // Salva nello storageService usando il fileIndex corretto
              _autoSave();

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Record aggiunto con successo")),
              );
            },
            child: const Text("Conferma"),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int indexInCurrent) {
    // Troviamo l'indice reale nel widget.data originale
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
        content: Text(
          "Vuoi eliminare ${_selectedRows.length} record selezionati?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                // Ordiniamo gli indici dal più grande al più piccolo per evitare errori di spostamento lista
                final sortedIndices = _selectedRows.toList()
                  ..sort((a, b) => b.compareTo(a));
                for (var index in sortedIndices) {
                  widget.data.removeAt(index);
                }
                _selectedRows.clear();

                // Aggiorna la vista corrente (filtri inclusi)
                if (_isSearching) {
                  _performSearch(_searchController.text);
                } else {
                  _currentData = List.from(widget.data);
                }
              });
              _autoSave(); // Persistenza multi-file
              Navigator.pop(context);
            },
            child: const Text("Elimina"),
          ),
        ],
      ),
    );
  }
}
