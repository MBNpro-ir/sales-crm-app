import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../widgets/common.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  String? _selectedProvince;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
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
        SectionCard(
          title: 'نقشه تعاملی ایران',
          trailing: _selectedProvince == null
              ? const Text('برای مشاهده تعداد مشتریان روی استان کلیک کنید')
              : Text(
                  '$_selectedProvince: ${formatPersianInteger(provinces[_selectedProvince] ?? 0)} مشتری',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
          child: _IranProvinceMap(
            counts: provinces,
            selectedProvince: _selectedProvince,
            onSelected: (value) => setState(() => _selectedProvince = value),
          ),
        ),
        if (_selectedProvince != null) ...[
          const SizedBox(height: 18),
          SectionCard(
            title: 'مشتریان استان $_selectedProvince',
            child: Builder(
              builder: (context) {
                final customers = store.customers
                    .where((item) => item.province == _selectedProvince)
                    .toList();
                if (customers.isEmpty) {
                  return const EmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'مشتری ثبت نشده است',
                    message: 'در اطلاعات مشتری، استان را تکمیل کنید.',
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: customers
                      .map(
                        (item) => Chip(
                          avatar: item.isVip
                              ? const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 18,
                                )
                              : null,
                          label: Text(item.displayName),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
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

class _IranProvinceMap extends StatelessWidget {
  const _IranProvinceMap({
    required this.counts,
    required this.selectedProvince,
    required this.onSelected,
  });

  final Map<String, int> counts;
  final String? selectedProvince;
  final ValueChanged<String> onSelected;

  static const _markers = <(String, String, double, double)>[
    ('آذربایجان غربی', 'آ.غ', .12, .16),
    ('آذربایجان شرقی', 'آ.ش', .23, .13),
    ('اردبیل', 'ارد', .31, .08),
    ('گیلان', 'گیل', .40, .10),
    ('مازندران', 'ماز', .51, .13),
    ('گلستان', 'گل', .63, .14),
    ('خراسان شمالی', 'خ.ش', .73, .17),
    ('خراسان رضوی', 'خ.ر', .82, .25),
    ('خراسان جنوبی', 'خ.ج', .78, .48),
    ('سیستان و بلوچستان', 'س.ب', .82, .72),
    ('هرمزگان', 'هرم', .62, .82),
    ('کرمان', 'کر', .66, .64),
    ('یزد', 'یزد', .55, .53),
    ('اصفهان', 'اص', .44, .49),
    ('فارس', 'فارس', .49, .68),
    ('بوشهر', 'بوش', .38, .76),
    ('کهگیلویه و بویراحمد', 'ک.ب', .34, .63),
    ('چهارمحال و بختیاری', 'چ.ب', .37, .54),
    ('خوزستان', 'خوز', .23, .63),
    ('ایلام', 'ایلام', .13, .52),
    ('کرمانشاه', 'کرش', .17, .40),
    ('کردستان', 'کرد', .22, .31),
    ('همدان', 'همد', .30, .38),
    ('لرستان', 'لر', .29, .50),
    ('مرکزی', 'مرک', .39, .38),
    ('قم', 'قم', .46, .36),
    ('تهران', 'تهر', .49, .28),
    ('البرز', 'الب', .44, .25),
    ('قزوین', 'قزو', .37, .27),
    ('زنجان', 'زنج', .30, .25),
    ('سمنان', 'سمن', .61, .30),
  ];

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.85,
    child: LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _IranOutlinePainter(Theme.of(context).colorScheme),
            ),
          ),
          ..._markers.map((marker) {
            final (province, short, x, y) = marker;
            final count = counts[province] ?? 0;
            final selected = selectedProvince == province;
            return Positioned(
              left: constraints.maxWidth * x - 22,
              top: constraints.maxHeight * y - 15,
              child: Tooltip(
                message: '$province — ${formatPersianInteger(count)} مشتری',
                child: InkWell(
                  onTap: () => onSelected(province),
                  borderRadius: BorderRadius.circular(99),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : count > 0
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      count > 0
                          ? '$short ${formatPersianInteger(count)}'
                          : short,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

class _IranOutlinePainter extends CustomPainter {
  const _IranOutlinePainter(this.colors);

  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .08, size.height * .12)
      ..lineTo(size.width * .27, size.height * .04)
      ..lineTo(size.width * .48, size.height * .08)
      ..lineTo(size.width * .72, size.height * .12)
      ..lineTo(size.width * .92, size.height * .31)
      ..lineTo(size.width * .86, size.height * .52)
      ..lineTo(size.width * .91, size.height * .84)
      ..lineTo(size.width * .69, size.height * .91)
      ..lineTo(size.width * .55, size.height * .82)
      ..lineTo(size.width * .39, size.height * .88)
      ..lineTo(size.width * .22, size.height * .73)
      ..lineTo(size.width * .09, size.height * .57)
      ..lineTo(size.width * .15, size.height * .37)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primaryContainer.withValues(alpha: .45)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _IranOutlinePainter oldDelegate) =>
      oldDelegate.colors != colors;
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
