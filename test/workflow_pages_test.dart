import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/core/crm_store.dart';
import 'package:sales_crm/ui/pages/calendar_page.dart';
import 'package:sales_crm/ui/pages/calls_page.dart';
import 'package:sales_crm/ui/pages/customers_page.dart';
import 'package:sales_crm/ui/pages/documents_page.dart';
import 'package:sales_crm/ui/pages/invoices_page.dart';
import 'package:sales_crm/ui/pages/market_page.dart';
import 'package:sales_crm/ui/pages/opportunities_page.dart';
import 'package:sales_crm/ui/pages/products_page.dart';
import 'package:sales_crm/ui/pages/reports_page.dart';
import 'package:sales_crm/ui/pages/tasks_page.dart';

void main() {
  testWidgets('all requested CRM workflow pages render safely', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = CrmStore();
    final pages = <Widget>[
      CustomersPage(store: store),
      CallsPage(store: store),
      OpportunitiesPage(store: store),
      TasksPage(store: store),
      CalendarPage(store: store),
      DocumentsPage(store: store, mode: DocumentPageMode.quote),
      DocumentsPage(store: store, mode: DocumentPageMode.order),
      InvoicesPage(store: store, direction: 'خرید'),
      InvoicesPage(store: store, direction: 'فروش'),
      ProductsPage(store: store),
      ReportsPage(store: store),
      MarketPage(store: store),
    ];

    for (final page in pages) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(padding: const EdgeInsets.all(16), child: page),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: page.runtimeType.toString(),
      );
    }
  });
}
