import 'package:flutter/material.dart';

class CsvDetailPage extends StatelessWidget {
  final Map<String, dynamic> record;
  final List<String> allColumns;

  const CsvDetailPage({super.key, required this.record, required this.allColumns});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dettaglio Record"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: allColumns.map((col) {
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
                  Text(
                    record[col]?.toString() ?? "N/A",
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