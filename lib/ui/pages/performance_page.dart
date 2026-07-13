import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final owners = _owners();
    final totalOrders = store.orders
        .where((order) => order.direction == 'فروش')
        .fold(0, (total, order) => total + order.totalAmount);
    final completedTasks = store.tasks.where((task) => task.isDone).length;
    return ListView(
      children: [
        const CrmPageHeader(
          title: 'عملکرد فروش و اهداف تیم',
          subtitle:
              'خروجی فرصت‌ها، وظایف و اسناد فروش را در یک نمای مدیریتی برای هر کارشناس بررسی کنید.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'فروش سفارش‌ها',
                value: compactMoney(totalOrders),
                icon: Icons.payments_outlined,
                color: const Color(0xff12966b),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'پایپ‌لاین وزنی',
                value: compactMoney(store.weightedPipeline),
                icon: Icons.account_tree_outlined,
                color: const Color(0xff8349d6),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'نرخ موفقیت تماس',
                value: store.calls.isEmpty
                    ? '۰٪'
                    : '${(store.successfulCalls * 100 / store.calls.length).round()}٪',
                icon: Icons.phone_callback_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'وظایف تکمیل‌شده',
                value: '$completedTasks از ${store.tasks.length}',
                icon: Icons.task_alt_rounded,
                color: const Color(0xffe58a00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'عملکرد کارشناسان فروش',
          child: owners.isEmpty
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'داده‌ای برای عملکرد تیم وجود ندارد',
                  message:
                      'با ثبت فرصت و وظیفه برای کارشناسان، گزارش عملکرد ایجاد می‌شود.',
                )
              : CrmTableScroll(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('کارشناس')),
                      DataColumn(label: Text('فرصت‌های باز')),
                      DataColumn(label: Text('پایپ‌لاین وزنی')),
                      DataColumn(label: Text('وظایف باز')),
                      DataColumn(label: Text('وظایف انجام‌شده')),
                    ],
                    rows: owners.map((owner) {
                      final opportunities = store.opportunities
                          .where((item) => item.ownerName == owner)
                          .toList();
                      final activeOpportunities = opportunities
                          .where(
                            (item) =>
                                item.stage != 'برنده شده' &&
                                item.stage != 'از دست رفته',
                          )
                          .length;
                      final weighted = opportunities.fold(
                        0,
                        (sum, item) => sum + item.weightedAmount,
                      );
                      final tasks = store.tasks
                          .where((item) => item.ownerName == owner)
                          .toList();
                      return DataRow(
                        cells: [
                          DataCell(Text(owner)),
                          DataCell(Text(activeOpportunities.toString())),
                          DataCell(Text(compactMoney(weighted))),
                          DataCell(
                            Text(
                              tasks
                                  .where((item) => !item.isDone)
                                  .length
                                  .toString(),
                            ),
                          ),
                          DataCell(
                            Text(
                              tasks
                                  .where((item) => item.isDone)
                                  .length
                                  .toString(),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'مرکز پورسانت و اهداف',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryLine(
                label: 'مبنای فعلی فروش',
                value: compactMoney(totalOrders),
                color: const Color(0xff12966b),
              ),
              const SizedBox(height: 12),
              _SummaryLine(
                label: 'تعداد سفارش‌های فروش',
                value: store.salesOrders.toString(),
                color: const Color(0xff0b63ce),
              ),
              const SizedBox(height: 12),
              Text(
                'برای محاسبه قطعی پورسانت، نرخ‌ها و قواعد پرداخت هر سازمان باید در تنظیمات سازمان تعریف شود؛ این گزارش مبنای شفاف محاسبه را آماده می‌کند.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _owners() {
    final owners = <String>{};
    for (final opportunity in store.opportunities) {
      if (opportunity.ownerName.isNotEmpty) owners.add(opportunity.ownerName);
    }
    for (final task in store.tasks) {
      if (task.ownerName.isNotEmpty) owners.add(task.ownerName);
    }
    return owners.toList()..sort();
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
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
