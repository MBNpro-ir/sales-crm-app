import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'crm_store.dart';
import 'models.dart';
import '../ui/widgets/common.dart';

class CrmReportService {
  const CrmReportService._();

  static Future<String?> exportExcel({
    required String suggestedName,
    required String sheetName,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName.endsWith('.xlsx')
          ? suggestedName
          : '$suggestedName.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (location == null) return null;
    final workbook = Excel.createExcel();
    final sheet = workbook[sheetName];
    sheet.appendRow(headers.map<CellValue>(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(
        row
            .map<CellValue>(
              (value) => switch (value) {
                int number => IntCellValue(number),
                double number => DoubleCellValue(number),
                bool flag => BoolCellValue(flag),
                _ => TextCellValue(value?.toString() ?? ''),
              },
            )
            .toList(),
      );
    }
    if (sheetName != 'Sheet1') workbook.delete('Sheet1');
    final bytes = workbook.encode();
    if (bytes == null) throw StateError('ساخت فایل اکسل ناموفق بود.');
    await XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: suggestedName,
    ).saveTo(location.path);
    return location.path;
  }

  static Future<String?> exportCsv({
    required String suggestedName,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName.endsWith('.csv')
          ? suggestedName
          : '$suggestedName.csv',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return null;
    String cell(Object? value) =>
        '"${(value?.toString() ?? '').replaceAll('"', '""')}"';
    final content = <String>[
      headers.map(cell).join(','),
      ...rows.map((row) => row.map(cell).join(',')),
    ].join('\r\n');
    await XFile.fromData(
      Uint8List.fromList([0xef, 0xbb, 0xbf, ...utf8.encode(content)]),
      mimeType: 'text/csv',
      name: suggestedName,
    ).saveTo(location.path);
    return location.path;
  }

  static Future<List<List<String>>?> pickExcelRows() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (file == null) return null;
    final workbook = Excel.decodeBytes(await file.readAsBytes());
    final table = workbook.tables.values.firstOrNull;
    if (table == null) return const [];
    return table.rows
        .map(
          (row) => row
              .map((cell) => _cellText(cell?.value))
              .map((value) => value.trim())
              .toList(),
        )
        .toList();
  }

  static Future<String?> saveJsonFile({
    required String suggestedName,
    required Map<String, dynamic> data,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName.endsWith('.json')
          ? suggestedName
          : '$suggestedName.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return null;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: suggestedName,
    ).saveTo(location.path);
    return location.path;
  }

  static Future<Map<String, dynamic>?> pickJsonObject() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) return null;
    final decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
    if (decoded is! Map) throw const FormatException('فایل JSON معتبر نیست.');
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _cellText(CellValue? value) => switch (value) {
    null => '',
    TextCellValue item => item.value.toString(),
    IntCellValue item => item.value.toString(),
    DoubleCellValue item => item.value.toString(),
    BoolCellValue item => item.value ? 'true' : 'false',
    DateCellValue item => item.toString(),
    DateTimeCellValue item => item.toString(),
    TimeCellValue item => item.toString(),
    FormulaCellValue item => item.formula,
  };

  static Future<void> copyTable({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final text = <String>[
      headers.join('\t'),
      ...rows.map((row) => row.map((value) => value ?? '').join('\t')),
    ].join('\n');
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// Opens the shared report workspace before the platform print dialog.
  /// Every list report uses this path, so filtering, column customization and
  /// total/certain/detail views behave consistently across the application.
  static Future<void> printTable({
    required BuildContext context,
    required CrmStore store,
    required String title,
    required List<String> headers,
    required List<List<Object?>> rows,
    String subtitle = '',
    List<DateTime?>? rowDates,
    Set<int> numericColumns = const {},
  }) async {
    final prepared = await _showTablePreview(
      context: context,
      store: store,
      title: title,
      subtitle: subtitle,
      headers: headers,
      rows: rows,
      rowDates: rowDates,
      numericColumns: numericColumns,
    );
    if (prepared == null) return;
    await _printPreparedTable(title: title, report: prepared);
  }

  static Future<void> printDocument({
    required BuildContext context,
    required CrmStore store,
    required String title,
    required String number,
    required String customer,
    required String direction,
    required String status,
    required List<CrmDocumentLine> lineItems,
    required int totalAmount,
    String notes = '',
  }) async {
    final rows = lineItems
        .map(
          (item) => <Object?>[
            item.productCode,
            item.description,
            item.quantity,
            item.unit,
            item.unitPrice,
            item.discountPercent,
            item.taxAmount,
            item.totalAmount,
          ],
        )
        .toList();
    final prepared = await _showTablePreview(
      context: context,
      store: store,
      title: '$title $number',
      subtitle:
          'طرف حساب: $customer | نوع: $direction | وضعیت: $status${notes.trim().isEmpty ? '' : ' | توضیحات: $notes'}',
      headers: const [
        'کد کالا',
        'شرح',
        'مقدار',
        'واحد',
        'مبلغ واحد',
        'تخفیف درصدی',
        'ارزش افزوده',
        'مبلغ کل',
      ],
      rows: rows,
      rowDates: null,
      numericColumns: const {2, 4, 5, 6, 7},
    );
    if (prepared == null) return;
    final fonts = await _fonts();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(font: fonts.$2, fontSize: 20),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 14),
                pw.Wrap(
                  spacing: 24,
                  runSpacing: 6,
                  children: [
                    pw.Text('شماره: $number'),
                    pw.Text('طرف حساب: $customer'),
                    pw.Text('نوع: $direction'),
                    pw.Text('وضعیت: $status'),
                  ],
                ),
                pw.SizedBox(height: 16),
                if (prepared.rows.isEmpty)
                  pw.Text('ردیفی برای نمایش انتخاب نشده است.')
                else
                  _table(
                    prepared.headers,
                    prepared.rows,
                    fonts,
                    columnWidths: prepared.columnWidths,
                  ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'جمع مبلغ کل سند: ${formatPersianInteger(totalAmount, grouping: true)} ریال',
                  style: pw.TextStyle(font: fonts.$2, fontSize: 13),
                  textAlign: pw.TextAlign.left,
                ),
                if (notes.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Text('توضیحات: $notes'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name: '$title $number',
      onLayout: (_) => document.save(),
    );
  }

  static Future<_PreparedReport?> _showTablePreview({
    required BuildContext context,
    required CrmStore store,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<Object?>> rows,
    required List<DateTime?>? rowDates,
    required Set<int> numericColumns,
  }) {
    return showDialog<_PreparedReport>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReportPreviewDialog(
        title: title,
        store: store,
        subtitle: subtitle,
        headers: headers,
        rows: rows,
        rowDates: rowDates,
        numericColumns: numericColumns,
      ),
    );
  }

  static Future<void> _printPreparedTable({
    required String title,
    required _PreparedReport report,
  }) async {
    final fonts = await _fonts();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(font: fonts.$2, fontSize: 18),
                ),
                if (report.subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    report.subtitle,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
                pw.SizedBox(height: 14),
                _table(
                  report.headers,
                  report.rows,
                  fonts,
                  columnWidths: report.columnWidths,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(name: title, onLayout: (_) => document.save());
  }

  static Future<String?> _savePreparedPdf({
    required String title,
    required _PreparedReport report,
  }) async {
    final location = await getSaveLocation(
      suggestedName: '${title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')}.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return null;
    final fonts = await _fonts();
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(font: fonts.$2, fontSize: 18),
                ),
                if (report.subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    report.subtitle,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
                pw.SizedBox(height: 14),
                _table(
                  report.headers,
                  report.rows,
                  fonts,
                  columnWidths: report.columnWidths,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    await XFile.fromData(
      await document.save(),
      mimeType: 'application/pdf',
      name: '$title.pdf',
    ).saveTo(location.path);
    return location.path;
  }

  static pw.Widget _table(
    List<String> headers,
    List<List<Object?>> rows,
    (pw.Font, pw.Font) fonts, {
    List<double>? columnWidths,
  }) {
    pw.Widget cell(Object? value, {bool heading = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        value?.toString() ?? '',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: heading ? fonts.$2 : fonts.$1, fontSize: 7.5),
      ),
    );
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      columnWidths: columnWidths == null
          ? const {}
          : {
              for (var index = 0; index < columnWidths.length; index++)
                index: pw.FlexColumnWidth(columnWidths[index]),
            },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((item) => cell(item, heading: true)).toList(),
        ),
        ...rows.map((row) => pw.TableRow(children: row.map(cell).toList())),
      ],
    );
  }

  static Future<(pw.Font, pw.Font)> _fonts() async {
    final regular = await rootBundle.load(
      'assets/fonts/Vazirmatn-UI-FD-Regular.ttf',
    );
    final bold = await rootBundle.load('assets/fonts/Vazirmatn-UI-FD-Bold.ttf');
    return (pw.Font.ttf(regular), pw.Font.ttf(bold));
  }
}

class _ReportEntry {
  const _ReportEntry(this.values, this.date);

  final List<Object?> values;
  final DateTime? date;
}

class _ReportSort {
  const _ReportSort(this.column, this.ascending);

  final int column;
  final bool ascending;

  Map<String, dynamic> toJson() => {'column': column, 'ascending': ascending};
}

class _PreparedReport {
  const _PreparedReport({
    required this.headers,
    required this.rows,
    required this.subtitle,
    required this.columnWidths,
  });

  final List<String> headers;
  final List<List<Object?>> rows;
  final String subtitle;
  final List<double> columnWidths;
}

class _ReportPreviewDialog extends StatefulWidget {
  const _ReportPreviewDialog({
    required this.store,
    required this.title,
    required this.subtitle,
    required this.headers,
    required this.rows,
    required this.rowDates,
    required this.numericColumns,
  });

  final CrmStore store;
  final String title;
  final String subtitle;
  final List<String> headers;
  final List<List<Object?>> rows;
  final List<DateTime?>? rowDates;
  final Set<int> numericColumns;

  @override
  State<_ReportPreviewDialog> createState() => _ReportPreviewDialogState();
}

class _ReportPreviewDialogState extends State<_ReportPreviewDialog> {
  final _search = TextEditingController();
  late List<int> _order;
  late Set<int> _visible;
  late Map<int, TextEditingController> _filters;
  late Map<int, double> _widths;
  List<_ReportSort> _sorts = const [];
  DateTime? _from;
  DateTime? _to;
  String _level = 'تفصیلی';
  int? _groupColumn;
  int? _sortColumn;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.headers.length, (index) => index);
    _visible = _order.toSet();
    _filters = {for (final index in _order) index: TextEditingController()};
    _widths = {for (final index in _order) index: 150};
    _groupColumn = _order.isEmpty ? null : _order.first;
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _filters.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<_ReportEntry> _entries() {
    final needle = _search.text.trim().toLowerCase();
    final entries = <_ReportEntry>[];
    for (var rowIndex = 0; rowIndex < widget.rows.length; rowIndex++) {
      final original = widget.rows[rowIndex];
      final row = List<Object?>.generate(
        widget.headers.length,
        (index) => index < original.length ? original[index] : '',
      );
      final date = widget.rowDates != null && rowIndex < widget.rowDates!.length
          ? widget.rowDates![rowIndex]
          : null;
      if (_from != null &&
          (date == null || date.isBefore(_startOfDay(_from!)))) {
        continue;
      }
      if (_to != null && (date == null || date.isAfter(_endOfDay(_to!)))) {
        continue;
      }
      if (needle.isNotEmpty &&
          !row.any(
            (value) => value.toString().toLowerCase().contains(needle),
          )) {
        continue;
      }
      var matches = true;
      for (final entry in _filters.entries) {
        final filter = entry.value.text.trim().toLowerCase();
        if (filter.isNotEmpty &&
            !row[entry.key].toString().toLowerCase().contains(filter)) {
          matches = false;
          break;
        }
      }
      if (matches) entries.add(_ReportEntry(row, date));
    }
    if (_sorts.isNotEmpty) {
      entries.sort((left, right) {
        for (final sort in _sorts) {
          final result = _compare(
            left.values[sort.column],
            right.values[sort.column],
          );
          if (result != 0) return sort.ascending ? result : -result;
        }
        return 0;
      });
    }
    return entries;
  }

  _PreparedReport _prepared() {
    final entries = _entries();
    final columns = _order.where(_visible.contains).toList();
    final range = [
      if (_from != null) 'از ${formatJalaliDate(_from!)}',
      if (_to != null) 'تا ${formatJalaliDate(_to!)}',
    ].join(' ');
    final subtitle = [
      widget.subtitle,
      'سطح گزارش: $_level',
      if (range.isNotEmpty) range,
      'تعداد: ${formatPersianInteger(entries.length)}',
    ].where((item) => item.isNotEmpty).join(' | ');
    if (_level == 'تفصیلی' || _groupColumn == null) {
      return _PreparedReport(
        headers: columns.map((index) => widget.headers[index]).toList(),
        rows: entries
            .map(
              (entry) => columns.map((index) => entry.values[index]).toList(),
            )
            .toList(),
        subtitle: subtitle,
        columnWidths: columns.map((index) => _widths[index] ?? 150).toList(),
      );
    }
    final includeDay = _level == 'معین' && widget.rowDates != null;
    final groups = <String, List<_ReportEntry>>{};
    for (final entry in entries) {
      final label = entry.values[_groupColumn!].toString().trim().isEmpty
          ? 'نامشخص'
          : entry.values[_groupColumn!].toString();
      final day = includeDay && entry.date != null
          ? formatJalaliDate(entry.date!)
          : '';
      groups.putIfAbsent('$label\u0000$day', () => []).add(entry);
    }
    final numeric = columns.where(widget.numericColumns.contains).toList();
    final headers = <String>[
      widget.headers[_groupColumn!],
      if (includeDay) 'تاریخ',
      'تعداد',
      ...numeric.map((index) => 'جمع ${widget.headers[index]}'),
    ];
    final rows = groups.entries.map((group) {
      final parts = group.key.split('\u0000');
      return <Object?>[
        parts.first,
        if (includeDay) parts.last,
        formatPersianInteger(group.value.length),
        ...numeric.map(
          (index) => formatPersianInteger(
            group.value.fold<int>(
              0,
              (sum, entry) => sum + _numeric(entry.values[index]),
            ),
            grouping: true,
          ),
        ),
      ];
    }).toList();
    return _PreparedReport(
      headers: headers,
      rows: rows,
      subtitle: subtitle,
      columnWidths: List<double>.filled(headers.length, 150),
    );
  }

  Future<void> _pickDate({required bool from}) async {
    final current = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _configureColumns() async {
    var order = [..._order];
    var visible = {..._visible};
    final widths = {..._widths};
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('شخصی‌سازی، جابه‌جایی و فیلتر ستون‌ها'),
          content: SizedBox(
            width: 620,
            height: 520,
            child: ReorderableListView.builder(
              itemCount: order.length,
              onReorderItem: (oldIndex, newIndex) {
                setDialogState(() {
                  final item = order.removeAt(oldIndex);
                  order.insert(newIndex, item);
                });
              },
              itemBuilder: (context, position) {
                final index = order[position];
                return ListTile(
                  key: ValueKey(index),
                  leading: const Icon(Icons.drag_indicator_rounded),
                  title: Text(widget.headers[index]),
                  subtitle: Column(
                    children: [
                      TextField(
                        controller: _filters[index],
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'فیلتر این ستون',
                        ),
                      ),
                      Row(
                        children: [
                          const Text('عرض ستون'),
                          Expanded(
                            child: Slider(
                              value: widths[index] ?? 150,
                              min: 80,
                              max: 360,
                              divisions: 28,
                              onChanged: (value) =>
                                  setDialogState(() => widths[index] = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: visible.contains(index),
                    onChanged: (value) => setDialogState(() {
                      if (value) {
                        visible.add(index);
                      } else if (visible.length > 1) {
                        visible.remove(index);
                      }
                    }),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final controller in _filters.values) {
                  controller.clear();
                }
                setDialogState(() {
                  order = List.generate(
                    widget.headers.length,
                    (index) => index,
                  );
                  visible = order.toSet();
                  widths
                    ..clear()
                    ..addEntries(order.map((index) => MapEntry(index, 150)));
                });
              },
              child: const Text('بازنشانی'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('اعمال'),
            ),
          ],
        ),
      ),
    );
    if (apply == true) {
      setState(() {
        _order = order;
        _visible = visible;
        _widths = widths;
        if (_groupColumn != null && !_visible.contains(_groupColumn)) {
          _groupColumn = _order.firstWhere(_visible.contains);
        }
      });
    }
  }

  Future<void> _saveTemplate() async {
    final name = TextEditingController();
    var shared = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ذخیره قالب گزارش'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'نام قالب'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: shared,
                  title: const Text('اشتراک قالب بین کاربران'),
                  subtitle: const Text(
                    'قالب از طریق سرور با کاربران این فضای کاری همگام می‌شود.',
                  ),
                  onChanged: (value) => setDialogState(() => shared = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );
    final templateName = name.text.trim();
    name.dispose();
    if (accepted != true || templateName.isEmpty) return;
    final existing = widget.store.reportTemplates
        .where(
          (item) =>
              item.reportTitle == widget.title &&
              item.name == templateName &&
              item.ownerKey == widget.store.reportTemplateOwnerKey,
        )
        .firstOrNull;
    await widget.store.saveReportTemplate(
      id: existing?.id,
      reportTitle: widget.title,
      name: templateName,
      shared: shared,
      settings: {
        'order': _order,
        'visible': _visible.toList(),
        'widths': _widths.map((key, value) => MapEntry(key.toString(), value)),
        'filters': _filters.map(
          (key, value) => MapEntry(key.toString(), value.text),
        ),
        'search': _search.text,
        'from': _from?.toUtc().toIso8601String(),
        'to': _to?.toUtc().toIso8601String(),
        'level': _level,
        'group': _groupColumn,
        'sorts': _sorts.map((item) => item.toJson()).toList(),
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('قالب «$templateName» ذخیره شد.')));
    }
  }

  Future<void> _loadTemplate() async {
    final templates =
        widget.store.reportTemplates
            .where(
              (item) =>
                  item.reportTitle == widget.title &&
                  (item.shared ||
                      item.ownerKey == widget.store.reportTemplateOwnerKey),
            )
            .toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    if (!mounted) return;
    final selected = await showDialog<CrmReportTemplate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قالب‌های گزارش'),
        content: SizedBox(
          width: 520,
          height: 380,
          child: templates.isEmpty
              ? const Center(
                  child: Text('قالبی برای این گزارش ذخیره نشده است.'),
                )
              : ListView.builder(
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final item = templates[index];
                    return ListTile(
                      leading: Icon(
                        item.shared
                            ? Icons.groups_outlined
                            : Icons.person_outline_rounded,
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        item.shared
                            ? 'قالب اشتراکی — ${item.ownerName}'
                            : 'قالب شخصی',
                      ),
                      onTap: () => Navigator.pop(context, item),
                      trailing:
                          item.ownerKey == widget.store.reportTemplateOwnerKey
                          ? IconButton(
                              tooltip: 'حذف قالب',
                              onPressed: () async {
                                await widget.store.deleteReportTemplate(item);
                                if (context.mounted) Navigator.pop(context);
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    final settings = selected.settings;
    final valid = _order.toSet();
    final order = (settings['order'] as List? ?? const [])
        .map((item) => int.tryParse(item.toString()))
        .whereType<int>()
        .where(valid.contains)
        .toList();
    final visible = (settings['visible'] as List? ?? const [])
        .map((item) => int.tryParse(item.toString()))
        .whereType<int>()
        .where(valid.contains)
        .toSet();
    final widths = (settings['widths'] as Map? ?? const {}).map(
      (key, value) => MapEntry(
        int.tryParse(key.toString()) ?? -1,
        double.tryParse(value.toString()) ?? 150,
      ),
    )..remove(-1);
    final filters = (settings['filters'] as Map? ?? const {}).map(
      (key, value) =>
          MapEntry(int.tryParse(key.toString()) ?? -1, value.toString()),
    )..remove(-1);
    final sorts = (settings['sorts'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => _ReportSort(
            int.tryParse(item['column']?.toString() ?? '') ?? -1,
            item['ascending'] != false,
          ),
        )
        .where((item) => valid.contains(item.column))
        .toList();
    setState(() {
      _order = [...order, ..._order.where((item) => !order.contains(item))];
      if (visible.isNotEmpty) _visible = visible;
      _widths.addAll(widths);
      for (final entry in _filters.entries) {
        entry.value.text = filters[entry.key] ?? '';
      }
      _search.text = settings['search']?.toString() ?? '';
      _from = DateTime.tryParse(settings['from']?.toString() ?? '')?.toLocal();
      _to = DateTime.tryParse(settings['to']?.toString() ?? '')?.toLocal();
      _level = settings['level']?.toString() ?? _level;
      final group = int.tryParse(settings['group']?.toString() ?? '');
      if (group != null && valid.contains(group)) _groupColumn = group;
      _sorts = sorts;
      _sortColumn = sorts.firstOrNull?.column;
      _sortAscending = sorts.firstOrNull?.ascending ?? true;
    });
  }

  Future<void> _configureMultiSort() async {
    final selected = <int, bool>{
      for (final item in _sorts) item.column: item.ascending,
    };
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('مرتب‌سازی چندمرحله‌ای گزارش'),
          content: SizedBox(
            width: 500,
            height: 440,
            child: ListView(
              children: _order.map((index) {
                final active = selected.containsKey(index);
                return CheckboxListTile(
                  value: active,
                  title: Text(widget.headers[index]),
                  subtitle: active
                      ? Text(selected[index]! ? 'صعودی' : 'نزولی')
                      : null,
                  secondary: active
                      ? IconButton(
                          onPressed: () => setDialogState(
                            () => selected[index] = !selected[index]!,
                          ),
                          icon: Icon(
                            selected[index]!
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                          ),
                        )
                      : null,
                  onChanged: (value) => setDialogState(() {
                    value == true
                        ? selected[index] = true
                        : selected.remove(index);
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('اعمال'),
            ),
          ],
        ),
      ),
    );
    if (applied != true) return;
    setState(() {
      _sorts = _order
          .where(selected.containsKey)
          .map((index) => _ReportSort(index, selected[index]!))
          .toList();
      _sortColumn = _sorts.firstOrNull?.column;
      _sortAscending = _sorts.firstOrNull?.ascending ?? true;
    });
  }

  Future<void> _exportPrepared(String format, _PreparedReport prepared) async {
    switch (format) {
      case 'excel':
        await CrmReportService.exportExcel(
          suggestedName: '${widget.title}.xlsx',
          sheetName: widget.title.length > 31
              ? widget.title.substring(0, 31)
              : widget.title,
          headers: prepared.headers,
          rows: prepared.rows,
        );
      case 'csv':
        await CrmReportService.exportCsv(
          suggestedName: '${widget.title}.csv',
          headers: prepared.headers,
          rows: prepared.rows,
        );
      case 'pdf':
        await CrmReportService._savePreparedPdf(
          title: widget.title,
          report: prepared,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepared = _prepared();
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.preview_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text('پیش‌نمایش و تنظیم گزارش: ${widget.title}')),
        ],
      ),
      content: SizedBox(
        width: 1120,
        height: 660,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'جست‌وجوی سراسری گزارش',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                if (widget.rowDates != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(from: true),
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _from == null
                          ? 'از تاریخ'
                          : 'از ${formatJalaliDate(_from!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(from: false),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      _to == null ? 'تا تاریخ' : 'تا ${formatJalaliDate(_to!)}',
                    ),
                  ),
                ],
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    initialValue: _level,
                    decoration: const InputDecoration(labelText: 'سطح گزارش'),
                    items: const ['کل', 'معین', 'تفصیلی']
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _level = value ?? _level),
                  ),
                ),
                if (_level != 'تفصیلی' && _order.isNotEmpty)
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<int>(
                      initialValue: _groupColumn,
                      decoration: const InputDecoration(
                        labelText: 'گروه‌بندی گزارش',
                      ),
                      items: _order
                          .where(_visible.contains)
                          .map(
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(widget.headers[index]),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _groupColumn = value),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _configureColumns,
                  icon: const Icon(Icons.view_column_outlined),
                  label: const Text('ستون‌ها و فیلترها'),
                ),
                OutlinedButton.icon(
                  onPressed: _configureMultiSort,
                  icon: const Icon(Icons.sort_rounded),
                  label: const Text('مرتب‌سازی چندمرحله‌ای'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'قالب گزارش',
                  onSelected: (value) {
                    if (value == 'save') _saveTemplate();
                    if (value == 'load') _loadTemplate();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'save',
                      child: Text('ذخیره قالب گزارش'),
                    ),
                    PopupMenuItem(
                      value: 'load',
                      child: Text('قالب‌های شخصی و اشتراکی'),
                    ),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.bookmarks_outlined, size: 18),
                    label: Text('قالب گزارش'),
                  ),
                ),
                Text('${formatPersianInteger(prepared.rows.length)} ردیف'),
              ],
            ),
            const SizedBox(height: 14),
            if (prepared.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  prepared.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: prepared.rows.isEmpty
                    ? const Center(child: Text('ردیفی مطابق تنظیمات پیدا نشد.'))
                    : Builder(
                        builder: (context) {
                          final rawColumns = _order
                              .where(_visible.contains)
                              .toList();
                          final detailed = _level == 'تفصیلی';
                          final columns = prepared.headers.asMap().entries.map((
                            entry,
                          ) {
                            final rawIndex =
                                detailed && entry.key < rawColumns.length
                                ? rawColumns[entry.key]
                                : null;
                            return CrmTableColumn<List<Object?>>(
                              id: rawIndex == null
                                  ? 'summary_${entry.key}'
                                  : 'report_$rawIndex',
                              label: entry.value,
                              value: (row) => entry.key < row.length
                                  ? row[entry.key]?.toString() ?? ''
                                  : '',
                              sortValue: rawIndex == null
                                  ? null
                                  : (row) => entry.key < row.length
                                        ? row[entry.key]
                                        : null,
                              filterable: rawIndex != null,
                              numeric:
                                  rawIndex != null &&
                                  widget.numericColumns.contains(rawIndex),
                              initialWidth: rawIndex == null
                                  ? 150
                                  : (_widths[rawIndex] ?? 150),
                            );
                          }).toList();
                          return Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: CrmTableScroll(
                                child: CrmDataGridSurface<List<Object?>>(
                                  columns: columns,
                                  rows: prepared.rows,
                                  showRowNumbers: false,
                                  sortColumnId: detailed && _sortColumn != null
                                      ? 'report_$_sortColumn'
                                      : null,
                                  sortAscending: _sortAscending,
                                  onSort: detailed
                                      ? (columnId, ascending) {
                                          final rawIndex = int.tryParse(
                                            columnId.replaceFirst(
                                              'report_',
                                              '',
                                            ),
                                          );
                                          if (rawIndex == null) return;
                                          setState(() {
                                            _sortColumn = rawIndex;
                                            _sortAscending = ascending;
                                            _sorts = [
                                              _ReportSort(rawIndex, ascending),
                                            ];
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await CrmReportService.copyTable(
              headers: prepared.headers,
              rows: prepared.rows,
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('نمای گزارش کپی شد.')),
              );
            }
          },
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('کپی'),
        ),
        PopupMenuButton<String>(
          enabled: prepared.rows.isNotEmpty,
          tooltip: 'خروجی گزارش',
          onSelected: (value) => _exportPrepared(value, prepared),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'pdf', child: Text('خروجی PDF')),
            PopupMenuItem(value: 'excel', child: Text('خروجی Excel')),
            PopupMenuItem(value: 'csv', child: Text('خروجی CSV')),
          ],
          child: const Chip(
            avatar: Icon(Icons.download_outlined, size: 18),
            label: Text('خروجی'),
          ),
        ),
        FilledButton.icon(
          onPressed: prepared.rows.isEmpty
              ? null
              : () => Navigator.pop(context, prepared),
          icon: const Icon(Icons.print_outlined),
          label: const Text('ارسال برای پرینت'),
        ),
      ],
    );
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  static int _numeric(Object? value) {
    final normalized = toEnglishDigits(
      value?.toString() ?? '',
    ).replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(normalized) ?? 0;
  }

  static int _compare(Object? left, Object? right) {
    if (left is num && right is num) return left.compareTo(right);
    if (left is DateTime && right is DateTime) return left.compareTo(right);
    return left.toString().toLowerCase().compareTo(
      right.toString().toLowerCase(),
    );
  }
}
