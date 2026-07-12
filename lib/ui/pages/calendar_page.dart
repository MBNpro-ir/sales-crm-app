import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final events = <_CalendarEvent>[
      ...store.tasks
          .where((task) => task.dueAt != null && !task.isDone)
          .map(
            (task) => _CalendarEvent(
              date: task.dueAt!,
              title: task.title,
              subtitle: task.customerName + ' • ' + task.taskType,
              color: task.isOverdue
                  ? const Color(0xffd84b4b)
                  : const Color(0xff0b63ce),
              icon: Icons.task_alt_rounded,
            ),
          ),
      ...store.calls
          .where((call) => call.nextFollowUp != null)
          .map(
            (call) => _CalendarEvent(
              date: call.nextFollowUp!,
              title: 'پیگیری تماس: ' + call.subject,
              subtitle: call.customerName,
              color: const Color(0xffe58a00),
              icon: Icons.phone_in_talk_rounded,
            ),
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return ListView(
      children: [
        CrmPageHeader(
          title: 'تقویم فروش و پیگیری',
          subtitle:
              'جلسه‌ها، پیگیری‌های تماس و وظایف سررسیددار را در یک نما ببینید.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'رویدادهای آینده',
                value: events.length.toString(),
                icon: Icons.calendar_month_outlined,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'پیگیری تماس',
                value: store.calls
                    .where((call) => call.nextFollowUp != null)
                    .length
                    .toString(),
                icon: Icons.phone_callback_outlined,
                color: const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                title: 'وظیفه سررسید گذشته',
                value: store.overdueTasks.toString(),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xffd84b4b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'برنامه‌ی پیش‌رو',
          child: events.isEmpty
              ? const EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'رویدادی در تقویم ندارید',
                  message:
                      'برای تماس‌ها پیگیری و برای مشتری‌ها وظیفه تعریف کنید.',
                )
              : Column(
                  children: events.map((event) {
                    return _CalendarTile(event: event);
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.event});

  final _CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(event.icon, color: event.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  event.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            compactDate(event.date),
            style: TextStyle(color: event.color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
