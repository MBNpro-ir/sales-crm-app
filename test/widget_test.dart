import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/core/crm_store.dart';
import 'package:sales_crm/ui/app_shell.dart';
import 'package:sales_crm/ui/widgets/common.dart';

void main() {
  testWidgets('basic Persian UI renders in RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Text('فروش‌یار CRM'),
        ),
      ),
    );

    expect(find.text('فروش‌یار CRM'), findsOneWidget);
  });

  testWidgets('sidebar is right-aligned and has one safe menu control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: AppShell(store: CrmStore())));

    expect(find.byType(ListTile), findsWidgets);
    expect(tester.getTopLeft(find.text('فروش‌یار CRM')).dx, greaterThan(1100));
    expect(find.byTooltip('جمع یا باز کردن منو'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'collapsed sidebar keeps its profile inside the available width',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = CrmStore();
      await store.setSidebarCollapsed(true);
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
    },
  );

  test('input direction follows Persian, Latin and numbers', () {
    expect(inputTextDirection('سلام'), TextDirection.rtl);
    expect(inputTextDirection('CRM 0.0.2'), TextDirection.ltr);
    expect(inputTextDirection('۱۲۳۴۵'), TextDirection.ltr);
  });
}
