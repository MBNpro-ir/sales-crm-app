import 'package:flutter/material.dart';

import '../widgets/common.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.checklist,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> checklist;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        CrmPageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.72)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, size: 36, color: Colors.white),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'زیرساخت ماژول آماده است',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'مدل دسترسی، همگام‌سازی و طراحی یکپارچه در تمام ماژول‌ها استفاده می‌شود.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'قابلیت‌های این بخش',
          child: Column(
            children: checklist.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'گام بعدی توسعه',
          child: Text(
            'این ماژول در ساختار دامنه و پنل مدیریت سرور پیش‌بینی شده است. '
            'پس از تأیید فرایند فروش، فیلدها و گزارش‌های اختصاصی آن به نسخه‌ی اجرایی افزوده می‌شود.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}
