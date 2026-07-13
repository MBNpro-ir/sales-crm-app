import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/ui/widgets/common.dart';

void main() {
  test('Rial amounts use Persian digits and three-digit grouping', () {
    expect(formatCompactMoney(1234567), '۱٬۲۳۴٬۵۶۷ ریال');
  });

  test('numeric fields reject letters and keep grouped Persian digits', () {
    const formatter = PersianNumberFormatter();
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '۱۲۳۴a۵۶۷'),
    );

    expect(value.text, '۱٬۲۳۴٬۵۶۷');
    expect(parsePersianInt(value.text), 1234567);
  });
}
