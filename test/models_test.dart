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
}
