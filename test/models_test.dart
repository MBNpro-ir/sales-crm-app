import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/core/models.dart';

void main() {
  test('customer tags loaded from SQLite are strongly typed', () {
    final customer = CrmCustomer.fromDatabase({
      'id': 'customer-1',
      'name': 'مشتری آزمون',
      'company': 'شرکت آزمون',
      'mobile': '09120000000',
      'phone': '',
      'province': 'تهران',
      'city': 'تهران',
      'activity_type': 'تولیدکننده',
      'status': 'فعال',
      'priority': 'بالا',
      'notes': '',
      'tags_json': '["VIP", 5]',
      'updated_at': '2026-07-12T00:00:00.000Z',
      'is_deleted': 0,
    });

    expect(customer.tags, <String>['VIP', '5']);
  });

  test('document line calculates discount, tax and payable total', () {
    const line = CrmDocumentLine(
      productCode: 'P-1',
      description: 'کالای آزمون',
      quantity: 10,
      unit: 'عدد',
      unitPrice: 100000,
      discountPercent: 10,
      taxPercent: 10,
    );

    expect(line.grossAmount, 1000000);
    expect(line.discountAmount, 100000);
    expect(line.netAmount, 900000);
    expect(line.taxAmount, 90000);
    expect(line.totalAmount, 990000);
  });

  test('quotes preserve direction and line items through sync JSON', () {
    final quote = CrmQuote.fromJson({
      'id': 'quote-1',
      'customer_id': 'customer-1',
      'customer_name': 'مشتری آزمون',
      'quote_number': 'PF-1',
      'direction': 'خرید',
      'status': 'تایید شده',
      'total_amount': 990000,
      'notes': '',
      'updated_at': '2026-07-14T00:00:00.000Z',
      'line_items': [
        {
          'product_code': 'P-1',
          'description': 'کالای آزمون',
          'quantity': 10,
          'unit': 'عدد',
          'unit_price': 100000,
          'discount_percent': 10,
          'tax_percent': 10,
        },
      ],
    });

    expect(quote.direction, 'خرید');
    expect(quote.lineItems.single.totalAmount, 990000);
    expect((quote.toJson()['line_items'] as List).length, 1);
  });
}
