import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final kpiWidth = width > 1450 ? 250.0 : 220.0;
    return ListView(
      children: [
        CrmPageHeader(
          title: 'داشبورد فروش',
          subtitle: 'نمای کلی فعالیت تیم و اولویت‌های امروز',
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('امروز'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: kpiWidth,
              child: KpiCard(
                title: 'کل مشتریان',
                value: store.customers.length.toString(),
                icon: Icons.people_alt_rounded,
                color: const Color(0xff0b63ce),
                change: 'داده‌های محلی آماده است',
              ),
            ),
            SizedBox(
              width: kpiWidth,
              child: KpiCard(
                title: 'مشتریان فعال',
                value: store.activeCustomers.toString(),
                icon: Icons.verified_user_outlined,
                color: const Color(0xff12966b),
                change: 'اولویت پیگیری امروز',
              ),
            ),
            SizedBox(
              width: kpiWidth,
              child: KpiCard(
                title: 'تماس‌های موفق',
                value: store.successfulCalls.toString(),
                icon: Icons.phone_in_talk_rounded,
                color: const Color(0xff8349d6),
                change: 'از ' + store.calls.length.toString() + ' تماس',
              ),
            ),
            SizedBox(
              width: kpiWidth,
              child: KpiCard(
                title: 'فروش ثبت‌شده',
                value: compactMoney(store.totalRevenue),
                icon: Icons.payments_outlined,
                color: const Color(0xffe58a00),
                change: 'براساس تماس‌های ثبت‌شده',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 1000;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.56
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'روند تماس‌های هفتگی',
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('گزارش کامل'),
                    ),
                    child: const SizedBox(height: 220, child: _ContactTrend()),
                  ),
                ),
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.40
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'وضعیت تماس‌ها',
                    child: _ContactStatus(store: store),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 1000;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.60
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'آخرین تماس‌ها',
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('مشاهده همه'),
                    ),
                    child: _RecentCalls(store: store),
                  ),
                ),
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.36
                      : constraints.maxWidth,
                  child: SectionCard(
                    title: 'پیگیری‌های مهم',
                    child: _FollowUps(store: store),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ContactStatus extends StatelessWidget {
  const _ContactStatus({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.calls.isEmpty ? 1 : store.calls.length;
    final successful = store.successfulCalls / total;
    final unsuccessful =
        ((total - store.successfulCalls - store.followUpCalls) / total).clamp(
          0.0,
          1.0,
        );
    return Row(
      children: [
        SizedBox(
          width: 124,
          height: 124,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: successful,
                strokeWidth: 12,
                color: const Color(0xff12966b),
                backgroundColor: const Color(0xffe8edf5),
              ),
              Center(
                child: Text(
                  (successful * 100).round().toString() + '%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            children: [
              _LegendRow(
                label: 'موفق',
                value: store.successfulCalls.toString(),
                color: const Color(0xff12966b),
              ),
              const SizedBox(height: 12),
              _LegendRow(
                label: 'پیگیری',
                value: store.followUpCalls.toString(),
                color: const Color(0xffe58a00),
              ),
              const SizedBox(height: 12),
              _LegendRow(
                label: 'سایر',
                value: (unsuccessful * total).round().toString(),
                color: const Color(0xffd84b4b),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
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
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _RecentCalls extends StatelessWidget {
  const _RecentCalls({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    if (store.calls.isEmpty) {
      return const EmptyState(
        icon: Icons.phone_missed_outlined,
        title: 'تماسی ثبت نشده است',
        message: 'اولین تماس را از صفحه تماس‌ها ثبت کنید.',
      );
    }
    return Column(
      children: store.calls.take(5).map((call) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                child: Icon(
                  call.direction == 'ورودی'
                      ? Icons.call_received_rounded
                      : Icons.call_made_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      call.subject,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: call.status),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FollowUps extends StatelessWidget {
  const _FollowUps({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final followUps = store.calls
        .where((call) => call.nextFollowUp != null)
        .take(4)
        .toList();
    if (followUps.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_outlined,
        title: 'پیگیری بازی ندارید',
        message: 'زمان پیگیری تماس بعدی را هنگام ثبت تماس تعیین کنید.',
      );
    }
    return Column(
      children: followUps.map((call) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  call.customerName + ' — ' + call.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                compactDate(call.nextFollowUp!),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ContactTrend extends StatelessWidget {
  const _ContactTrend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _TrendPainter(
        lineColor: colors.primary,
        gridColor: colors.outlineVariant.withValues(alpha: 0.65),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.lineColor, required this.gridColor});

  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 1; index < 5; index++) {
      final y = size.height * index / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    const values = [0.22, 0.37, 0.31, 0.55, 0.48, 0.72, 0.83];
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height - (size.height * values[index]);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = lineColor.withValues(alpha: 0.11),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final y = size.height - (size.height * values[index]);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = lineColor);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
