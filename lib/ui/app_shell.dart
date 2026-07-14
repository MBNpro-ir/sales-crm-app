import 'package:flutter/material.dart';

import '../core/crm_store.dart';
import 'pages/calendar_page.dart';
import 'pages/calls_page.dart';
import 'pages/customers_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/documents_page.dart';
import 'pages/guide_page.dart';
import 'pages/invoices_page.dart';
import 'pages/market_page.dart';
import 'pages/opportunities_page.dart';
import 'pages/performance_page.dart';
import 'pages/products_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/tasks_page.dart';
import 'widgets/common.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});

  final CrmStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String? _initialCallStatus;

  static const _items = [
    _NavigationItem('داشبورد', Icons.dashboard_rounded),
    _NavigationItem('مشتریان', Icons.people_alt_rounded),
    _NavigationItem('تماس‌ها و جلسات', Icons.phone_in_talk_rounded),
    _NavigationItem('فرصت‌های خرید و فروش', Icons.track_changes_rounded),
    _NavigationItem('پیگیری و وظایف', Icons.task_alt_rounded),
    _NavigationItem('تقویم خرید و فروش', Icons.calendar_month_outlined),
    _NavigationItem('پیش‌فاکتورها', Icons.request_quote_outlined),
    _NavigationItem('سفارش‌ها', Icons.shopping_cart_outlined),
    _NavigationItem('فاکتور خرید', Icons.receipt_long_outlined),
    _NavigationItem('فاکتور فروش', Icons.receipt_outlined),
    _NavigationItem('کالا و موجودی', Icons.inventory_2_outlined),
    _NavigationItem('گزارش خرید و فروش', Icons.bar_chart_rounded),
    _NavigationItem('تحلیل‌ها (BI)', Icons.query_stats_outlined),
    _NavigationItem('نقشه بازار', Icons.public_outlined),
    _NavigationItem('عملکرد فروش', Icons.workspace_premium_outlined),
    _NavigationItem('مرکز دانش فروش', Icons.school_outlined),
    _NavigationItem('تنظیمات', Icons.settings_outlined),
  ];

  Widget _page() {
    switch (_selectedIndex) {
      case 0:
        return DashboardPage(
          store: widget.store,
          onOpenCalls: (status) {
            setState(() {
              _initialCallStatus = status;
              _selectedIndex = 2;
            });
          },
        );
      case 1:
        return CustomersPage(store: widget.store);
      case 2:
        return CallsPage(
          key: ValueKey(_initialCallStatus),
          store: widget.store,
          initialStatus: _initialCallStatus,
        );
      case 3:
        return OpportunitiesPage(store: widget.store);
      case 4:
        return TasksPage(store: widget.store);
      case 5:
        return CalendarPage(store: widget.store);
      case 6:
        return DocumentsPage(store: widget.store, mode: DocumentPageMode.quote);
      case 7:
        return DocumentsPage(store: widget.store, mode: DocumentPageMode.order);
      case 8:
        return InvoicesPage(store: widget.store, direction: 'خرید');
      case 9:
        return InvoicesPage(store: widget.store, direction: 'فروش');
      case 10:
        return ProductsPage(store: widget.store);
      case 11:
        return ReportsPage(store: widget.store);
      case 12:
        return ReportsPage(store: widget.store, analyticsOnly: true);
      case 13:
        return MarketPage(store: widget.store);
      case 14:
        return PerformancePage(store: widget.store);
      case 15:
        return const GuidePage();
      case 16:
      default:
        return SettingsPage(store: widget.store);
    }
  }

  void _selectPage(int index, {bool closeDrawer = false}) {
    setState(() {
      _selectedIndex = index;
      _initialCallStatus = null;
    });
    if (closeDrawer) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 980;
    final sidebar = _Sidebar(
      selectedIndex: _selectedIndex,
      items: _items,
      store: widget.store,
      collapsed: compact ? false : widget.store.sidebarCollapsed,
      onSelect: (index) => _selectPage(index, closeDrawer: compact),
    );
    return Scaffold(
      key: _scaffoldKey,
      drawer: compact ? Drawer(width: 292, child: sidebar) : null,
      body: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      children: [
                        _TopBar(
                          store: widget.store,
                          sidebarCollapsed: widget.store.sidebarCollapsed,
                          onMenuPressed: compact
                              ? () => _scaffoldKey.currentState?.openDrawer()
                              : () => widget.store.setSidebarCollapsed(
                                  !widget.store.sidebarCollapsed,
                                ),
                          compact: compact,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(
                              widget.store.largeTouchTargets ? 28 : 24,
                            ),
                            child: SoftPageSwitcher(
                              pageId: _selectedIndex,
                              child: _page(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!compact) sidebar,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.store,
    required this.sidebarCollapsed,
    required this.onMenuPressed,
    required this.compact,
  });

  final CrmStore store;
  final bool sidebarCollapsed;
  final VoidCallback onMenuPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = compact || constraints.maxWidth < 760;
          return Container(
            height: store.largeTouchTargets ? 86 : 76,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.65),
                ),
              ),
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: compact
                      ? 'باز کردن منوی اصلی'
                      : 'جمع یا باز کردن منوی اصلی',
                  child: IconButton(
                    onPressed: onMenuPressed,
                    tooltip: compact ? 'منو' : 'جمع یا باز کردن منو',
                    icon: Icon(
                      compact
                          ? Icons.menu_rounded
                          : sidebarCollapsed
                          ? Icons.keyboard_double_arrow_left_rounded
                          : Icons.keyboard_double_arrow_right_rounded,
                    ),
                  ),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'جست‌وجو در مشتریان، فعالیت‌ها و فرصت‌های فروش',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                Tooltip(
                  message: 'تغییر سریع حالت روشن یا تیره',
                  child: IconButton(
                    onPressed: store.toggleTheme,
                    icon: Icon(
                      store.themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: store.syncing
                      ? 'همگام‌سازی در حال انجام است'
                      : 'همگام‌سازی داده‌ها',
                  child: narrow
                      ? IconButton.filledTonal(
                          tooltip: 'همگام‌سازی',
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
                          icon: store.syncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  store.online
                                      ? Icons.cloud_sync_outlined
                                      : Icons.cloud_off_outlined,
                                ),
                        )
                      : FilledButton.tonalIcon(
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
                          icon: store.syncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  store.online
                                      ? Icons.cloud_sync_outlined
                                      : Icons.cloud_off_outlined,
                                ),
                          label: Text(
                            store.syncing ? 'در حال همگام‌سازی' : 'همگام‌سازی',
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.items,
    required this.store,
    required this.collapsed,
    required this.onSelect,
  });

  final int selectedIndex;
  final List<_NavigationItem> items;
  final CrmStore store;
  final bool collapsed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = collapsed ? 88.0 : 272.0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedContainer(
        duration: store.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: width,
        child: Material(
          color: const Color(0xff082651),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    collapsed ? 14 : 18,
                    18,
                    collapsed ? 14 : 18,
                    14,
                  ),
                  child: Row(
                    mainAxisAlignment: collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'فروش‌یار CRM',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(color: Color(0x337f9ac3), height: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 10 : 10,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = index == selectedIndex;
                      final tile = collapsed
                          ? Material(
                              color: selected
                                  ? colors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => onSelect(index),
                                child: SizedBox(
                                  height: 52,
                                  child: Center(
                                    child: Icon(
                                      item.icon,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xffbfd0e8),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                selected: selected,
                                selectedTileColor: colors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minLeadingWidth: 28,
                                leading: Icon(
                                  item.icon,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xffbfd0e8),
                                ),
                                title: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xffdce8f8),
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                                onTap: () => onSelect(index),
                              ),
                            );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: collapsed
                            ? Tooltip(message: item.label, child: tile)
                            : tile,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(collapsed ? 12 : 16),
                  child: Tooltip(
                    message: collapsed ? store.userName : '',
                    child: Container(
                      padding: EdgeInsets.all(collapsed ? 8 : 12),
                      decoration: BoxDecoration(
                        color: const Color(0xff0f376f),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: collapsed
                          ? Center(
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: colors.primaryContainer,
                                child: Text(
                                  store.userName.isEmpty
                                      ? 'ک'
                                      : store.userName[0],
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colors.primaryContainer,
                                  child: Text(
                                    store.userName.isEmpty
                                        ? 'ک'
                                        : store.userName[0],
                                    style: TextStyle(
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        store.userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        store.online
                                            ? 'متصل به سرور'
                                            : 'حالت آفلاین',
                                        style: const TextStyle(
                                          color: Color(0xffafc7e9),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
