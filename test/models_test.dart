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

  test('call calculates discount, value added tax and final total', () {
    final call = CrmCall.fromJson({
      'id': 'call-1',
      'customer_id': 'customer-1',
      'customer_name': 'مشتری آزمون',
      'subject': 'فروش آزمایشی',
      'type': 'تلفنی',
      'status': 'موفق',
      'call_at': '2026-07-15T09:30:00.000Z',
      'duration_minutes': 10,
      'notes': '',
      'trade_type': 'فروش',
      'quantity': 2,
      'unit_price': 500000,
      'amount': 1000000,
      'discount_amount': 100000,
      'tax_percent': 10,
      'updated_at': '2026-07-15T09:30:00.000Z',
    });

    expect(call.subtotal, 1000000);
    expect(call.netAmount, 900000);
    expect(call.taxAmount, 90000);
    expect(call.totalAmount, 990000);
    expect(call.hasTradeOutcome, isTrue);
    expect(call.toJson()['discount_amount'], 100000);
  });

  test('opportunity preserves product and target location through JSON', () {
    final opportunity = CrmOpportunity.fromJson({
      'id': 'opportunity-1',
      'customer_id': 'customer-1',
      'customer_name': 'مشتری آزمون',
      'title': 'فرصت فروش',
      'stage': 'نیازسنجی',
      'amount': 2000000,
      'probability': 40,
      'notes': '',
      'owner_name': 'مدیر',
      'trade_type': 'فروش',
      'product_name': 'کالای آزمون',
      'province': 'تهران',
      'city': 'تهران',
      'updated_at': '2026-07-15T09:30:00.000Z',
    });

    expect(opportunity.productName, 'کالای آزمون');
    expect(opportunity.province, 'تهران');
    expect(opportunity.city, 'تهران');
    expect(opportunity.toJson()['city'], 'تهران');
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

  test('attachments preserve content and entity ownership through JSON', () {
    final attachment = CrmAttachment.fromJson({
      'id': 'attachment-1',
      'entity_type': 'customer',
      'entity_id': 'customer-1',
      'file_name': 'contract.pdf',
      'extension': 'pdf',
      'size_bytes': 4,
      'content_base64': 'dGVzdA==',
      'uploaded_by': 'مدیر',
      'updated_at': '2026-07-15T09:30:00.000Z',
    });

    expect(attachment.entityType, 'customer');
    expect(attachment.contentBase64, 'dGVzdA==');
    expect(attachment.toJson()['size_bytes'], 4);
  });

  test('audit log preserves old and new values through JSON', () {
    final entry = CrmAuditEntry.fromJson({
      'id': 'audit-1',
      'entity_type': 'customer',
      'entity_id': 'customer-1',
      'action': 'ویرایش',
      'user_name': 'مدیر',
      'old_value': {'status': 'فعال'},
      'new_value': {'status': 'غیرفعال'},
      'updated_at': '2026-07-15T09:30:00.000Z',
    });

    expect(entry.oldValue['status'], 'فعال');
    expect(entry.newValue['status'], 'غیرفعال');
    expect(entry.toJson()['user_name'], 'مدیر');
  });
}
