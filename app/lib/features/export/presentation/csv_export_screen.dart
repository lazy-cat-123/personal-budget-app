import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../features/finance/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';

class CsvExportScreen extends ConsumerStatefulWidget {
  const CsvExportScreen({super.key});

  @override
  ConsumerState<CsvExportScreen> createState() => _CsvExportScreenState();
}

class _CsvExportScreenState extends ConsumerState<CsvExportScreen> {
  static const _downloadsChannel = MethodChannel(
    'personal_budget_app/downloads',
  );

  DateTime? _fromDate;
  DateTime? _toDate;
  List<CsvExportFile> _lastFiles = const [];
  String? _lastExportPath;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CSV Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Full Backup',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Download all local data as separate CSV files on this device.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isExporting ? null : _saveAllData,
                  icon: const Icon(Icons.download),
                  label: const Text('Download All Data'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Transactions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFromDate: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _fromDate == null
                              ? 'From day'
                              : DateFormat.yMMMd().format(_fromDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isFromDate: false),
                        icon: const Icon(Icons.event),
                        label: Text(
                          _toDate == null
                              ? 'To day'
                              : DateFormat.yMMMd().format(_toDate!),
                        ),
                      ),
                    ),
                    if (_fromDate != null || _toDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear date filter',
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _isExporting ? null : _saveTransactions,
                      icon: const Icon(Icons.download),
                      label: const Text('Download Transactions'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isExporting ? null : _saveAllTransactions,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('All Transactions'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Last Export',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_lastExportPath != null) ...[
                  SelectableText('Saved to $_lastExportPath'),
                  const SizedBox(height: 8),
                ],
                if (_lastFiles.isEmpty)
                  const Text('No export downloaded yet in this session.'),
                for (final file in _lastFiles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description),
                    title: Text(file.fileName),
                    subtitle: Text('${file.content.length} characters'),
                    trailing: IconButton(
                      tooltip: 'Copy this CSV',
                      onPressed: () => _copyFile(file),
                      icon: const Icon(Icons.copy),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAllData() async {
    await _runExport(() async {
      final repository = ref.read(financeRepositoryProvider);
      final files = await repository.exportAllCsvFiles();
      final savedPath = await _saveCsvFiles('full_backup', files);
      setState(() {
        _lastFiles = files;
        _lastExportPath = savedPath;
      });
      _showSnackBar('All CSV files downloaded');
    });
  }

  Future<void> _saveTransactions() async {
    await _runExport(() async {
      final csv = await ref.read(financeRepositoryProvider).exportTransactionsCsv(
            from: _fromDate,
            to: _toDate,
          );
      final fileName = _transactionFileName();
      final file = CsvExportFile(fileName: fileName, content: csv);
      final savedPath = await _saveCsvFiles('transactions', [file]);
      setState(() {
        _lastFiles = [file];
        _lastExportPath = savedPath;
      });
      _showSnackBar('Transactions CSV downloaded');
    });
  }

  Future<void> _saveAllTransactions() async {
    await _runExport(() async {
      final csv = await ref.read(financeRepositoryProvider).exportTransactionsCsv();
      final file = CsvExportFile(fileName: 'transactions.csv', content: csv);
      final savedPath = await _saveCsvFiles('transactions', [file]);
      setState(() {
        _lastFiles = [file];
        _lastExportPath = savedPath;
        _fromDate = null;
        _toDate = null;
      });
      _showSnackBar('All transactions CSV downloaded');
    });
  }

  Future<void> _copyFile(CsvExportFile file) async {
    await Clipboard.setData(ClipboardData(text: file.content));
    _showSnackBar('${file.fileName} copied');
  }

  Future<void> _runExport(Future<void> Function() action) async {
    setState(() => _isExporting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<Directory> _createExportDirectory(String prefix) async {
    final root = await _exportRootDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directory = Directory(p.join(root.path, '${prefix}_$timestamp'));
    return directory.create(recursive: true);
  }

  Future<Directory> _exportRootDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        final directory = Directory(p.join(downloads.path, 'PersonalBudgetExports'));
        try {
          return await directory.create(recursive: true);
        } catch (_) {
          // Fall back to the app document directory when public Downloads is unavailable.
        }
      }
    }

    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'PersonalBudgetExports'))
        .create(recursive: true);
  }

  Future<File> _writeCsvFile(Directory directory, CsvExportFile exportFile) {
    final file = File(p.join(directory.path, exportFile.fileName));
    return file.writeAsString(exportFile.content, flush: true);
  }

  Future<String> _saveCsvFiles(String prefix, List<CsvExportFile> files) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final directoryName = '${prefix}_$timestamp';

    if (Platform.isAndroid) {
      final savedPaths = await _downloadsChannel.invokeMethod<List<Object?>>(
        'saveCsvFiles',
        {
          'directoryName': directoryName,
          'files': [
            for (final file in files)
              {'fileName': file.fileName, 'content': file.content},
          ],
        },
      );
      return savedPaths == null || savedPaths.isEmpty
          ? 'Downloads/PersonalBudgetExports/$directoryName'
          : savedPaths.length == 1
          ? savedPaths.first.toString()
          : 'Downloads/PersonalBudgetExports/$directoryName';
    }

    final directory = await _createExportDirectory(prefix);
    for (final file in files) {
      await _writeCsvFile(directory, file);
    }
    return files.length == 1
        ? p.join(directory.path, files.first.fileName)
        : directory.path;
  }

  String _transactionFileName() {
    final from = _fromDate == null ? 'start' : DateFormat('yyyyMMdd').format(_fromDate!);
    final to = _toDate == null ? 'today' : DateFormat('yyyyMMdd').format(_toDate!);
    return 'transactions_${from}_to_$to.csv';
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final currentValue = isFromDate ? _fromDate : _toDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(2000);
    final lastDate = isFromDate ? (_toDate ?? today) : today;
    final earliestDate = isFromDate ? firstDate : (_fromDate ?? firstDate);
    final fallbackInitial =
        currentValue ?? (isFromDate ? (_toDate ?? today) : today);
    final initialDate = fallbackInitial.isBefore(earliestDate)
        ? earliestDate
        : fallbackInitial.isAfter(lastDate)
        ? lastDate
        : fallbackInitial;
    final picked = await showDatePicker(
      context: context,
      firstDate: earliestDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );
    if (picked == null) return;

    final pickedDay = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      if (isFromDate) {
        _fromDate = pickedDay;
        if (_toDate != null && _toDate!.isBefore(pickedDay)) {
          _toDate = pickedDay;
        }
      } else {
        _toDate = pickedDay;
        if (_fromDate != null && _fromDate!.isAfter(pickedDay)) {
          _fromDate = pickedDay;
        }
      }
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
