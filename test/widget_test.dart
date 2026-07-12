import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/core/crm_store.dart';
import 'package:sales_crm/ui/app_shell.dart';

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

  testWidgets('sidebar ListTiles have a Material paint ancestor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: AppShell(store: CrmStore())));

    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
