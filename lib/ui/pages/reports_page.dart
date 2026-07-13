import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({
    super.key,
    required this.store,
    this.analyticsOnly = false,
  });

  final CrmStore store;
  final bool analyticsOnly;

  @override
  Widget build(BuildContext context) {
    final stages = <String, int>{};
    for (final opportunity in store.opportunities) {
      stages[opportunity.stage] = (stages[opportunity.stage] ?? 0) + 1;
    }
    final totalStages = stages.values.fold(0, (sum, value) => sum + value);
    final salesCalls = store.calls
        .where((call) => call.tradeType == 'فروش')
        .length;
    final purchaseCalls = store.calls
        .where((call) => call.tradeType == 'خرید')
        .length;
    return ListView(
      children: [
        CrmPageHeader(
          title: analyticsOnly ? 'تحلیل‌های فروش' : 'گزارش‌های فروش',
          subtitle: analyticsOnly
              ? 'شاخص‌های عملکرد، قیف فروش و نقطه‌های نیازمند توجه.'
              : 'خلاصه‌ی روزانه از تماس، خرید، فروش، سفارش و پیش‌فاکتور.',
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                showCrmNotice(
                  context,
                  'خروجی فایل در نسخه‌ی بعد به انتخاب محل ذخیره متصل می‌شود.',
                  type: CrmNoticeType.info,
                );
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('خروجی گزارش'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 260,
              child: KpiCard(
                title: 'فروش ثبت‌شده',
                value: compactMoney(store.totalRevenue),
                icon: Icons.trending_up_rounded,
                color: const Color(0xff12966b),
              ),
            ),
            SizedBox(
              width: 260,
              child: KpiCard(
                title: 'خرید ثبت‌شده',
                value: compactMoney(store.totalPurchase),
                icon: Icons.shopping_cart_outlined,
                color: const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 260,
              child: KpiCard(
                title: 'نرخ موفقیت تماس',
                value: store.calls.isEmpty
                    ? '۰٪'
                    : (store.successfulCalls * 100 / store.calls.length)
                              .round()
                              .toString() +
                          '%',
                icon: Icons.phone_callback_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 260,
              child: KpiCard(
                title: 'فرصت‌های باز',
                value: store.openOpportunities.toString(),
                icon: Icons.track_changes_outlined,
                color: const Color(0xff8349d6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 950;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.56
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'قیف فرصت‌های فروش',
                    child: _Funnel(stages: stages, total: totalStages),
                  ),
                ),
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.40
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'خلاصه فعالیت تجاری',
                    child: Column(
                      children: [
                        _ReportRow(
                          label: 'تماس‌های فروش',
                          value: salesCalls.toString(),
                          color: const Color(0xff12966b),
                        ),
                        const SizedBox(height: 14),
                        _ReportRow(
                          label: 'تماس‌های خرید',
                          value: purchaseCalls.toString(),
                          color: const Color(0xffe58a00),
                        ),
                        const SizedBox(height: 14),
                        _ReportRow(
                          label: 'پیش‌فاکتورهای فعال',
                          value: store.pendingQuotes.toString(),
                          color: const Color(0xff8349d6),
                        ),
                        const SizedBox(height: 14),
                        _ReportRow(
                          label: 'سفارش فروش',
                          value: store.salesOrders.toString(),
                          color: const Color(0xff0b63ce),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: analyticsOnly ? 'علت‌های نیازمند توجه' : 'گزارش تماس‌های اخیر',
          child: analyticsOnly
              ? Column(
                  children: [
                    _InsightRow(
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xffd84b4b),
                      title: 'پیگیری‌های سررسیدشده',
                      value: store.overdueTasks.toString() + ' وظیفه',
                    ),
                    _InsightRow(
                      icon: Icons.inventory_outlined,
                      color: const Color(0xffe58a00),
                      title: 'محصولات با موجودی کم',
                      value:
                          store.products
                              .where((product) => product.needsRestock)
                              .length
                              .toString() +
                          ' قلم',
                    ),
                    _InsightRow(
                      icon: Icons.phone_missed_outlined,
                      color: const Color(0xffd84b4b),
                      title: 'تماس‌های ناموفق',
                      value: store.unsuccessfulCalls.toString() + ' تماس',
                    ),
                  ],
                )
              : CrmTableScroll(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('مشتری')),
                      DataColumn(label: Text('موضوع')),
                      DataColumn(label: Text('نوع')),
                      DataColumn(label: Text('نتیجه')),
                      DataColumn(label: Text('خرید / فروش')),
                      DataColumn(label: Text('مبلغ')),
                    ],
                    rows: store.calls.take(10).map((call) {
                      return DataRow(
                        cells: [
                          DataCell(Text(call.customerName)),
                          DataCell(Text(call.subject)),
                          DataCell(Text(call.type)),
                          DataCell(StatusPill(label: call.status)),
                          DataCell(
                            Text(call.tradeType.isEmpty ? '—' : call.tradeType),
                          ),
                          DataCell(Text(compactMoney(call.amount))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Funnel extends StatelessWidget {
  const _Funnel({required this.stages, required this.total});

  final Map<String, int> stages;
  final int total;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'تماس اولیه',
      'نیازسنجی',
      'پیش‌فاکتور',
      'مذاکره',
      'برنده شده',
    ];
    const colors = [
      Color(0xff0b63ce),
      Color(0xff26a7a4),
      Color(0xffe58a00),
      Color(0xff8349d6),
      Color(0xff12966b),
    ];
    return Column(
      children: List.generate(labels.length, (index) {
        final value = stages[labels[index]] ?? 0;
        final fraction = total == 0 ? 0.0 : value / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(width: 88, child: Text(labels[index])),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 16,
                    color: colors[index],
                    backgroundColor: colors[index].withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 46,
                child: Text(
                  value.toString(),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
