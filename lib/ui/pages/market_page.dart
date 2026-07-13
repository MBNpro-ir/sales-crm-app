import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final provinces = _countBy(
      store.customers,
      (customer) => customer.province,
    );
    final sources = _countBy(
      store.customers,
      (customer) => customer.details['source'] ?? 'ثبت‌نشده',
    );
    final potentialCustomers = store.customers
        .where(
          (customer) =>
              customer.status == 'مشتری بالقوه' ||
              customer.priority == 'خیلی بالا' ||
              customer.priority == 'بالا',
        )
        .toList();
    final active = store.customers
        .where((customer) => customer.status == 'فعال')
        .length;
    return ListView(
      children: [
        const CrmPageHeader(
          title: 'نقشه بازار و جذب مشتری',
          subtitle:
              'پوشش جغرافیایی مشتریان، کانال‌های جذب و مشتریان بالقوه را برای برنامه‌ریزی فروش بررسی کنید.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 245,
              child: KpiCard(
                title: 'استان‌های تحت پوشش',
                value: provinces.length.toString(),
                icon: Icons.map_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 245,
              child: KpiCard(
                title: 'مشتریان فعال',
                value: active.toString(),
                icon: Icons.verified_user_outlined,
                color: const Color(0xff12966b),
              ),
            ),
            SizedBox(
              width: 245,
              child: KpiCard(
                title: 'نیازمند توجه',
                value: potentialCustomers.length.toString(),
                icon: Icons.radar_outlined,
                color: const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 245,
              child: KpiCard(
                title: 'کانال‌های جذب',
                value: sources.length.toString(),
                icon: Icons.hub_outlined,
                color: const Color(0xff8349d6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 920;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.58
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'پوشش بازار بر اساس استان',
                    child: _Distribution(
                      values: provinces,
                      emptyMessage:
                          'با تکمیل استان مشتریان، پوشش بازار اینجا نمایش داده می‌شود.',
                      color: const Color(0xff0b63ce),
                    ),
                  ),
                ),
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.38
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'منابع جذب مشتری',
                    child: _Distribution(
                      values: sources,
                      emptyMessage:
                          'منبع آشنایی مشتریان را در فرم مشتری تکمیل کنید.',
                      color: const Color(0xff8349d6),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'مشتریان بالقوه و اولویت‌دار',
          child: potentialCustomers.isEmpty
              ? const EmptyState(
                  icon: Icons.travel_explore_outlined,
                  title: 'موردی برای پیگیری وجود ندارد',
                  message:
                      'برای مشتریان جدید اولویت و وضعیت ارتباط را ثبت کنید.',
                )
              : CrmTableScroll(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    columns: const [
                      DataColumn(label: Text('مشتری')),
                      DataColumn(label: Text('استان / شهر')),
                      DataColumn(label: Text('منبع جذب')),
                      DataColumn(label: Text('وضعیت')),
                      DataColumn(label: Text('اولویت')),
                      DataColumn(label: Text('کالای مورد علاقه')),
                    ],
                    rows: potentialCustomers.map((customer) {
                      return DataRow(
                        cells: [
                          DataCell(Text(_customerLabel(customer))),
                          DataCell(
                            Text('${customer.province} / ${customer.city}'),
                          ),
                          DataCell(Text(customer.details['source'] ?? '—')),
                          DataCell(StatusPill(label: customer.status)),
                          DataCell(Text(customer.priority)),
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Text(
                                customer.details['interested_products'] ?? '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Map<String, int> _countBy(
    Iterable<CrmCustomer> customers,
    String Function(CrmCustomer customer) selector,
  ) {
    final result = <String, int>{};
    for (final customer in customers) {
      final key = selector(customer).trim();
      final normalized = key.isEmpty ? 'ثبت‌نشده' : key;
      result[normalized] = (result[normalized] ?? 0) + 1;
    }
    return result;
  }

  String _customerLabel(CrmCustomer customer) {
    return customer.company.isEmpty ? customer.name : customer.company;
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({
    required this.values,
    required this.emptyMessage,
    required this.color,
  });

  final Map<String, int> values;
  final String emptyMessage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'داده‌ای ثبت نشده است',
        message: emptyMessage,
      );
    }
    final entries = values.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    final maximum = entries.first.value;
    return Column(
      children: entries.take(7).map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: entry.value / maximum,
                    minHeight: 13,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                entry.value.toString(),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
