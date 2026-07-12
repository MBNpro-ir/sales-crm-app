import 'package:flutter/material.dart';

import '../widgets/common.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    const guides = [
      _GuideItem(
        icon: Icons.people_alt_rounded,
        color: Color(0xff0b63ce),
        title: '۱. ثبت مشتری',
        description:
            'اطلاعات اصلی، راه ارتباطی، آدرس، نوع فعالیت و اولویت را در دفترچه مشتریان ثبت کنید.',
      ),
      _GuideItem(
        icon: Icons.phone_in_talk_rounded,
        color: Color(0xff12966b),
        title: '۲. ثبت تماس یا جلسه',
        description:
            'نتیجه، موضوع، خرید یا فروش، کالا، مبلغ و تاریخ پیگیری را پس از هر ارتباط وارد کنید.',
      ),
      _GuideItem(
        icon: Icons.track_changes_rounded,
        color: Color(0xff8349d6),
        title: '۳. تبدیل به فرصت فروش',
        description:
            'برای مشتری علاقه‌مند فرصت بسازید و آن را از نیازسنجی تا پیش‌فاکتور و قرارداد در قیف حرکت دهید.',
      ),
      _GuideItem(
        icon: Icons.request_quote_outlined,
        color: Color(0xffe58a00),
        title: '۴. پیش‌فاکتور و سفارش',
        description:
            'پیش‌فاکتور را ثبت کنید، اعتبار آن را پیگیری کنید و پس از تایید، سفارش فروش یا خرید بسازید.',
      ),
      _GuideItem(
        icon: Icons.task_alt_rounded,
        color: Color(0xff12966b),
        title: '۵. پیگیری و گزارش',
        description:
            'کارهای سررسیددار را در تقویم ببینید و با گزارش‌ها نرخ موفقیت، فروش و خرید را بررسی کنید.',
      ),
    ];
    return ListView(
      children: [
        const CrmPageHeader(
          title: 'راهنمای جامع سیستم',
          subtitle: 'مسیر پیشنهادی استفاده از CRM فروش‌یار برای تیم فروش.',
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'شروع سریع',
          child: Column(
            children: guides.map((guide) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: guide.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(guide.icon, color: guide.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guide.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            guide.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'نکات کلیدی',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Tip(
                'هر تماس را با نتیجه و اقدام بعدی ثبت کنید؛ کیفیت داده از تعداد آن مهم‌تر است.',
              ),
              _Tip(
                'در فرصت فروش، مبلغ و احتمال موفقیت را به‌روز نگه دارید تا پیش‌بینی درآمد قابل اتکا باشد.',
              ),
              _Tip(
                'قبل از خروج از برنامه، وضعیت همگام‌سازی را در نوار بالا بررسی کنید.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideItem {
  const _GuideItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xff12966b),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
