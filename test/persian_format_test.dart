import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/ui/widgets/common.dart';

void main() {
  test('Rial amounts use Persian digits and three-digit grouping', () {
    expect(formatCompactMoney(1234567), '۱٬۲۳۴٬۵۶۷ ریال');
  });

  test(
    'identifier fields reject letters without grouping or losing zeroes',
    () {
      const formatter = PersianNumberFormatter();
      final value = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '۰۹۱۲a۳۴۵۶۷۸۹'),
      );

      expect(value.text, '۰۹۱۲۳۴۵۶۷۸۹');
      expect(value.text.contains('٬'), isFalse);
    },
  );

  test('Rial inputs are the only grouped numeric fields', () {
    const formatter = PersianNumberFormatter(grouping: true);
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '۱۲۳۴a۵۶۷'),
    );

    expect(value.text, '۱٬۲۳۴٬۵۶۷');
    expect(parsePersianInt(value.text), 1234567);
  });
}
