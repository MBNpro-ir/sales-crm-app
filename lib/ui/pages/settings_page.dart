import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        CrmPageHeader(
          title: 'تنظیمات و دسترس‌پذیری',
          subtitle:
              'ظاهر، خوانایی، پیمایش و همگام‌سازی را مطابق نیاز هر کاربر شخصی‌سازی کنید.',
          actions: [
            FilledButton.icon(
              onPressed: store.syncing
                  ? null
                  : () async {
                      await store.sync();
                      if (!context.mounted) return;
                      showCrmNotice(
                        context,
                        store.syncMessage,
                        type: store.online
                            ? CrmNoticeType.success
                            : CrmNoticeType.warning,
                      );
                    },
              icon: const Icon(Icons.sync_rounded),
              label: const Text('همگام‌سازی اکنون'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 930;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.48
                      : constraints.maxWidth,
                  child: _AccountCard(store: store),
                ),
                SizedBox(
                  width: wide
                      ? constraints.maxWidth * 0.48
                      : constraints.maxWidth,
                  child: _SyncCard(store: store),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _AppearanceCard(store: store),
        const SizedBox(height: 18),
        _CloseBehaviorCard(store: store),
        const SizedBox(height: 18),
        _AccessibilityCard(store: store),
        const SizedBox(height: 18),
        SectionCard(
          title: 'زبان، اعداد و تقویم',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingRow(
                icon: Icons.calendar_month_outlined,
                label: 'تقویم برنامه',
                value: formatJalaliDate(DateTime.now(), includeTime: true),
                color: const Color(0xff0b63ce),
              ),
              const SizedBox(height: 14),
              _SettingRow(
                icon: Icons.numbers_outlined,
                label: 'نمایش اعداد',
                value:
                    'فارسی، مثل ${formatPersianInteger(1234567, grouping: true)}',
                color: const Color(0xff8349d6),
              ),
              const SizedBox(height: 14),
              _SettingRow(
                icon: Icons.font_download_outlined,
                label: 'فونت رابط کاربری',
                value: 'Vazirmatn',
                color: const Color(0xff12966b),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'حساب کاربری',
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(store.userName.isEmpty ? 'ک' : store.userName[0]),
            ),
            title: Text(store.userName),
            subtitle: Text(store.organizationName),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded),
            title: const Text('خروج از حساب'),
            subtitle: const Text(
              'داده‌های همگام‌شدهٔ این دستگاه حذف نمی‌شوند.',
            ),
            onTap: store.logout,
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'وضعیت داده و سرور',
      child: Column(
        children: [
          _SettingRow(
            icon: store.online
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            label: 'اتصال سرور',
            value: store.online ? 'در دسترس' : 'در دسترس نیست',
            color: store.online
                ? const Color(0xff12966b)
                : const Color(0xffd84b4b),
          ),
          const SizedBox(height: 14),
          _SettingRow(
            icon: Icons.outbox_outlined,
            label: 'تغییرات در صف',
            value: '${formatPersianInteger(store.pendingOutboxCount)} مورد',
            color: const Color(0xffe58a00),
          ),
          const SizedBox(height: 14),
          _SettingRow(
            icon: Icons.storage_outlined,
            label: 'داده‌های محلی',
            value:
                '${formatPersianInteger(store.customers.length)} مشتری، ${formatPersianInteger(store.calls.length)} فعالیت',
            color: const Color(0xff0b63ce),
          ),
          const SizedBox(height: 16),
          SelectableText(
            store.apiBaseUrl,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'ظاهر و رنگ‌بندی',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حالت نمایش', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined),
                label: Text('سیستم'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('روشن'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('تیره'),
              ),
            ],
            selected: {store.themeMode},
            onSelectionChanged: (value) => store.setThemeMode(value.first),
          ),
          const SizedBox(height: 22),
          Text('رنگ اصلی', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: CrmAccent.values.map((accent) {
              final color = _accentColor(accent);
              final selected = store.accent == accent;
              return Semantics(
                button: true,
                label: 'رنگ ${_accentLabel(accent)}',
                selected: selected,
                child: Tooltip(
                  message: _accentLabel(accent),
                  child: InkWell(
                    onTap: () => store.setAccent(accent),
                    borderRadius: BorderRadius.circular(99),
                    child: AnimatedContainer(
                      duration: store.reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? colors.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: store.sidebarCollapsed,
            onChanged: store.setSidebarCollapsed,
            title: const Text('شروع با منوی جمع‌شده'),
            subtitle: const Text(
              'در حالت جمع‌شده فقط آیکون‌های منوی سمت راست نمایش داده می‌شوند.',
            ),
            secondary: const Icon(Icons.menu_open_rounded),
          ),
        ],
      ),
    );
  }
}

class _CloseBehaviorCard extends StatelessWidget {
  const _CloseBehaviorCard({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'رفتار بستن در ویندوز',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'در صورت انتخاب حالت Tray، پنجره مخفی می‌شود اما آیکون برنامه در ناحیهٔ اعلان ویندوز باقی می‌ماند. با کلیک روی آن یا گزینهٔ «باز کردن برنامه» دوباره پنجره نمایش داده می‌شود.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CloseBehavior>(
            initialValue: store.closeBehavior,
            decoration: const InputDecoration(
              labelText: 'هنگام زدن دکمه بستن',
              prefixIcon: Icon(Icons.power_settings_new_rounded),
            ),
            items: CloseBehavior.values
                .map(
                  (behavior) => DropdownMenuItem(
                    value: behavior,
                    child: Text(_closeBehaviorLabel(behavior)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) store.setCloseBehavior(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'منوی Tray شامل دو گزینهٔ «باز کردن برنامه» و «بستن کامل برنامه» است.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessibilityCard extends StatelessWidget {
  const _AccessibilityCard({required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'دسترس‌پذیری',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'اندازه متن',
            value:
                '${formatPersianInteger((store.textScale * 100).round())} درصد',
            child: Row(
              children: [
                const Icon(Icons.format_size_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اندازه متن',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
                        value: store.textScale,
                        min: 0.85,
                        max: 1.45,
                        divisions: 12,
                        label:
                            '${formatPersianInteger((store.textScale * 100).round())}٪',
                        onChanged: store.setTextScale,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${formatPersianInteger((store.textScale * 100).round())}٪',
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: store.highContrast,
            onChanged: store.setHighContrast,
            title: const Text('کنتراست بالا'),
            subtitle: const Text(
              'مرزها و تفاوت رنگ‌ها برای خوانایی بیشتر تقویت می‌شوند.',
            ),
            secondary: const Icon(Icons.contrast_rounded),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: store.boldText,
            onChanged: store.setBoldText,
            title: const Text('متن ضخیم‌تر'),
            subtitle: const Text(
              'متن رابط کاربری با وزن بیشتر نمایش داده می‌شود.',
            ),
            secondary: const Icon(Icons.format_bold_rounded),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: store.largeTouchTargets,
            onChanged: store.setLargeTouchTargets,
            title: const Text('ناحیه لمس بزرگ‌تر'),
            subtitle: const Text(
              'کنترل‌ها و فاصله‌ها برای استفادهٔ ساده‌تر بزرگ می‌شوند.',
            ),
            secondary: const Icon(Icons.touch_app_rounded),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: store.reduceMotion,
            onChanged: store.setReduceMotion,
            title: const Text('کاهش حرکت و انیمیشن'),
            subtitle: const Text(
              'انیمیشن‌های جابه‌جایی برای جلوگیری از خستگی بصری کاهش می‌یابند.',
            ),
            secondary: const Icon(Icons.motion_photos_off_outlined),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: 'پیش‌نمایش دسترس‌پذیری',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'پیش‌نمایش: این متن با تنظیمات فعلی شما نمایش داده می‌شود و تمام کنترل‌های کلیدی برچسب دسترس‌پذیر دارند.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

Color _accentColor(CrmAccent accent) {
  return switch (accent) {
    CrmAccent.ocean => const Color(0xff0b63ce),
    CrmAccent.emerald => const Color(0xff087f5b),
    CrmAccent.violet => const Color(0xff7044c4),
    CrmAccent.amber => const Color(0xffb76800),
    CrmAccent.rose => const Color(0xffb63a5d),
  };
}

String _accentLabel(CrmAccent accent) {
  return switch (accent) {
    CrmAccent.ocean => 'آبی',
    CrmAccent.emerald => 'سبز',
    CrmAccent.violet => 'بنفش',
    CrmAccent.amber => 'کهربایی',
    CrmAccent.rose => 'زرشکی',
  };
}

String _closeBehaviorLabel(CloseBehavior behavior) {
  return switch (behavior) {
    CloseBehavior.ask => 'هر بار بپرس',
    CloseBehavior.minimizeToTray => 'همیشه به Tray برود',
    CloseBehavior.exit => 'همیشه خروج کامل',
  };
}
