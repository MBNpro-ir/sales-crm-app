import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_crm/ui/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('professional grid exposes shared customization controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'crm_active_user_scope': 'organization::user',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CrmConfigurableDataTable<int>(
              tableId: 'test-grid',
              rows: List.generate(30, (index) => index + 1),
              columns: [
                CrmTableColumn(
                  id: 'value',
                  label: 'مقدار',
                  value: (item) => item.toString(),
                  sortValue: (item) => item,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('جستجو داخل جدول'), findsOneWidget);
    expect(find.text('ستون‌ها و چیدمان'), findsOneWidget);
    expect(find.text('مرتب‌سازی چندمرحله‌ای'), findsOneWidget);
    expect(find.text('انتخاب همه رکوردها'), findsOneWidget);
    expect(find.text('صفحه ۱ از ۲'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('صفحه بعد'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('صفحه بعد'));
    await tester.pumpAndSettle();
    expect(find.text('صفحه ۲ از ۲'), findsOneWidget);
  });
}
