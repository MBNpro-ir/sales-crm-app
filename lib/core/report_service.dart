import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'persian_format.dart';

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

  static Future<void> printTable({
    required String title,
    required List<String> headers,
    required List<List<Object?>> rows,
    String subtitle = '',
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
                if (subtitle.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
                ],
                pw.SizedBox(height: 14),
                _table(headers, rows, fonts),
              ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(name: title, onLayout: (_) => document.save());
  }

  static Future<void> printDocument({
    required String title,
    required String number,
    required String customer,
    required String direction,
    required String status,
    required List<CrmDocumentLine> lineItems,
    required int totalAmount,
    String notes = '',
  }) async {
    final fonts = await _fonts();
    final document = pw.Document();
    final rows = lineItems
        .map(
          (item) => <Object?>[
            item.productCode,
            item.description,
            formatPersianInteger(item.quantity),
            item.unit,
            formatPersianInteger(item.unitPrice),
            '${formatPersianInteger(item.discountPercent)}٪',
            formatPersianInteger(item.taxAmount),
            formatPersianInteger(item.totalAmount),
          ],
        )
        .toList();
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
                pw.SizedBox(height: 16),
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
                if (rows.isEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Text(
                      'این سند قدیمی فاقد ردیف کالاست؛ مبلغ کل ثبت‌شده نمایش داده می‌شود.',
                    ),
                  )
                else
                  _table(
                    const [
                      'کد کالا',
                      'شرح',
                      'مقدار',
                      'واحد',
                      'مبلغ واحد',
                      'تخفیف',
                      'ارزش افزوده',
                      'مبلغ کل',
                    ],
                    rows,
                    fonts,
                  ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'جمع مبلغ کل: ${formatPersianInteger(totalAmount)} ریال',
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

  static pw.Widget _table(
    List<String> headers,
    List<List<Object?>> rows,
    (pw.Font, pw.Font) fonts,
  ) {
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
