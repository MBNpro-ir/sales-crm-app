import 'package:shamsi_date/shamsi_date.dart';

const _latinDigits = '0123456789';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

String toPersianDigits(Object? value) {
  var result = value?.toString() ?? '';
  for (var index = 0; index < _latinDigits.length; index++) {
    result = result.replaceAll(_latinDigits[index], _persianDigits[index]);
  }
  return result.replaceAll('.', '٫').replaceAll(',', '٬');
}

String toEnglishDigits(String value) {
  var result = value
      .replaceAll('٬', '')
      .replaceAll(',', '')
      .replaceAll('٫', '.')
      .replaceAll('،', '');
  for (var index = 0; index < _persianDigits.length; index++) {
    result = result.replaceAll(_persianDigits[index], _latinDigits[index]);
  }
  return result;
}

int parsePersianInt(String value) {
  final normalized = toEnglishDigits(
    value,
  ).replaceAll(RegExp(r'[\s,،]'), '').trim();
  return int.tryParse(normalized) ?? 0;
}

String formatPersianInteger(int value, {bool grouping = false}) {
  final raw = value.abs().toString();
  final grouped = grouping
      ? raw.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => '٬')
      : raw;
  return '${value.isNegative ? '−' : ''}${toPersianDigits(grouped)}';
}

String formatCompactMoney(int amount) {
  // Values are stored and displayed in ریال throughout the product.  Keeping
  // the full grouped number also avoids an ambiguous abbreviated amount in
  // invoices, orders and audit tables.
  return '${formatPersianInteger(amount, grouping: true)} ریال';
}

String formatJalaliDate(DateTime value, {bool includeTime = false}) {
  final local = value.toLocal();
  final jalali = Jalali.fromDateTime(local);
  final date =
      '${jalali.year.toString().padLeft(4, '0')}/'
      '${jalali.month.toString().padLeft(2, '0')}/'
      '${jalali.day.toString().padLeft(2, '0')}';
  if (!includeTime) return toPersianDigits(date);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${toPersianDigits(date)}، ${toPersianDigits(time)}';
}
