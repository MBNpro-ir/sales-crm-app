import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';
import '../widgets/entity_tools.dart';
import 'calls_page.dart';
import 'documents_page.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key, required this.store, this.onOpenProducts});

  final CrmStore store;
  final VoidCallback? onOpenProducts;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();
  final _codeFilter = TextEditingController();
  final _nameFilter = TextEditingController();
  final _mobileFilter = TextEditingController();
  final _cityFilter = TextEditingController();
  String? _activityFilter;
  String? _statusFilter;
  String? _priorityFilter;
  String? _provinceFilter;
  String? _quickFilter;

  @override
  void dispose() {
    _search.dispose();
    _codeFilter.dispose();
    _nameFilter.dispose();
    _mobileFilter.dispose();
    _cityFilter.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CrmCustomer? customer]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _CustomerEditorDialog(store: widget.store, customer: customer),
    );
    if (!mounted || saved != true) return;
    showCrmNotice(
      context,
      customer == null ? 'مشتری ثبت شد.' : 'اطلاعات مشتری ویرایش شد.',
      type: CrmNoticeType.success,
    );
  }

  Future<void> _delete(CrmCustomer customer) async {
    final label = customer.company.isEmpty ? customer.name : customer.company;
    if (!await confirmDelete(context, label: label)) return;
    await widget.store.deleteCustomer(customer);
    if (mounted) {
      showCrmNotice(
        context,
        'مشتری حذف و برای همگام‌سازی صف شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  List<CrmCustomer> _filteredCustomers() {
    final needle = _search.text.trim().toLowerCase();
    return widget.store.customers.where((customer) {
      final matchesSearch =
          needle.isEmpty ||
          customer.name.toLowerCase().contains(needle) ||
          customer.company.toLowerCase().contains(needle) ||
          customer.mobile.contains(needle) ||
          customer.city.toLowerCase().contains(needle);
      return matchesSearch &&
          (_codeFilter.text.trim().isEmpty ||
              customer.customerCode.contains(_codeFilter.text.trim())) &&
          (_nameFilter.text.trim().isEmpty ||
              customer.displayName.toLowerCase().contains(
                _nameFilter.text.trim().toLowerCase(),
              )) &&
          (_mobileFilter.text.trim().isEmpty ||
              customer.mobile.contains(_mobileFilter.text.trim())) &&
          (_cityFilter.text.trim().isEmpty ||
              customer.city.toLowerCase().contains(
                _cityFilter.text.trim().toLowerCase(),
              )) &&
          (_activityFilter == null ||
              customer.activityType == _activityFilter) &&
          (_statusFilter == null || customer.status == _statusFilter) &&
          (_priorityFilter == null || customer.priority == _priorityFilter) &&
          (_provinceFilter == null || customer.province == _provinceFilter) &&
          _matchesQuickFilter(customer);
    }).toList();
  }

  bool _matchesQuickFilter(CrmCustomer customer) {
    final filter = _quickFilter;
    if (filter == null) return true;
    final calls = widget.store.calls
        .where((item) => item.customerId == customer.id)
        .toList();
    final opportunities = widget.store.opportunities
        .where((item) => item.customerId == customer.id)
        .toList();
    final lastCall = calls.isEmpty
        ? null
        : calls
              .map((item) => item.callAt)
              .reduce((left, right) => left.isAfter(right) ? left : right);
    final daysWithoutCall = lastCall == null
        ? 1 << 20
        : DateTime.now().difference(lastCall).inDays;
    return switch (filter) {
      'مشتری جدید' =>
        DateTime.now().difference(customer.updatedAt).inDays <= 30,
      'مشتری VIP' => customer.isVip,
      'بدون تماس ۱۵ تا ۲۰ روز' =>
        daysWithoutCall >= 15 && daysWithoutCall <= 20,
      'بدون تماس ۲۰ تا ۳۰ روز' => daysWithoutCall > 20 && daysWithoutCall <= 30,
      'بدون خرید' => !calls.any((item) => item.tradeType == 'خرید'),
      'بدون فروش' => !calls.any((item) => item.tradeType == 'فروش'),
      'فرصت فعال' => opportunities.any(
        (item) => !{'برنده شده', 'از دست رفته'}.contains(item.stage),
      ),
      'فرصت منقضی' => opportunities.any(
        (item) =>
            item.expectedClose != null &&
            item.expectedClose!.isBefore(DateTime.now()) &&
            !{'برنده شده', 'از دست رفته'}.contains(item.stage),
      ),
      'اولویت بالا' => {'بالا', 'خیلی بالا'}.contains(customer.priority),
      _ => true,
    };
  }

  Future<void> _showDetails(CrmCustomer customer) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _CustomerDetailsDialog(store: widget.store, customer: customer),
    );
  }

  List<List<Object?>> _rowsForExport(List<CrmCustomer> customers) => customers
      .map(
        (item) => <Object?>[
          item.customerCode,
          item.name,
          item.company,
          item.mobile,
          item.phone,
          item.province,
          item.city,
          item.activityType,
          item.status,
          item.priority,
          item.isVip ? 'بله' : 'خیر',
          item.details['email'] ?? '',
          item.details['address'] ?? '',
          item.tags.join(', '),
          item.notes,
        ],
      )
      .toList();

  static const _exportHeaders = [
    'کد مشتری',
    'نام مخاطب',
    'نام شرکت',
    'موبایل',
    'تلفن',
    'استان',
    'شهر',
    'نوع فعالیت',
    'وضعیت',
    'اولویت',
    'VIP',
    'ایمیل',
    'آدرس',
    'برچسب‌ها',
    'یادداشت',
  ];

  Future<void> _exportExcel() async {
    final rows = _filteredCustomers();
    final path = await CrmReportService.exportExcel(
      suggestedName: 'customers.xlsx',
      sheetName: 'مشتریان',
      headers: _exportHeaders,
      rows: _rowsForExport(rows),
    );
    if (mounted && path != null) {
      showCrmNotice(
        context,
        'خروجی اکسل مشتریان ذخیره شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _importExcel() async {
    final table = await CrmReportService.pickExcelRows();
    if (table == null || table.isEmpty) return;
    const aliases = <String, String>{
      'کد مشتری': 'customer_code',
      'نام مخاطب': 'name',
      'نام': 'name',
      'نام شرکت': 'company',
      'شرکت': 'company',
      'موبایل': 'mobile',
      'تلفن': 'phone',
      'استان': 'province',
      'شهر': 'city',
      'نوع فعالیت': 'activity_type',
      'وضعیت': 'status',
      'اولویت': 'priority',
      'VIP': 'is_vip',
      'وی آی پی': 'is_vip',
      'ایمیل': 'email',
      'آدرس': 'address',
      'برچسب‌ها': 'tags',
      'یادداشت': 'notes',
    };
    final headers = table.first.map((item) => aliases[item] ?? '').toList();
    final records = <Map<String, String>>[];
    for (final row in table.skip(1)) {
      final record = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        if (headers[index].isNotEmpty && index < row.length) {
          record[headers[index]] = row[index];
        }
      }
      records.add(record);
    }
    final count = await widget.store.importCustomerRows(records);
    if (mounted) {
      showCrmNotice(
        context,
        '${formatPersianInteger(count)} مشتری از اکسل ثبت یا به‌روزرسانی شد.',
        type: count == 0 ? CrmNoticeType.warning : CrmNoticeType.success,
      );
    }
  }

  Future<void> _openPhonebook([List<CrmCustomer>? source]) =>
      CrmReportService.printTable(
        context: context,
        title: 'دفترچه تلفن مشتریان',
        subtitle: 'نمایش کامل، فیلتر، مرتب‌سازی و شخصی‌سازی دفتر تلفن',
        headers: _exportHeaders,
        rows: _rowsForExport(source ?? _filteredCustomers()),
      );

  Future<void> _newCall(CrmCustomer customer) async {
    await showCrmCallEditor(
      context,
      store: widget.store,
      initialCustomerId: customer.id,
      onOpenProducts: widget.onOpenProducts,
    );
  }

  Future<void> _newQuote(CrmCustomer customer) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentEditorDialog(
        store: widget.store,
        mode: DocumentPageMode.quote,
        initialCustomerId: customer.id,
      ),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        'پیش‌فاکتور مشتری ثبت شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _newOrder(CrmCustomer customer) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentEditorDialog(
        store: widget.store,
        mode: DocumentPageMode.order,
        initialCustomerId: customer.id,
      ),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        'سفارش مشتری ثبت شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _backupTools([String? requestedAction]) async {
    final action =
        requestedAction ??
        await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تهیه و بازیابی پشتیبانی'),
            content: const Text(
              'نسخه پشتیبان شامل تمام اطلاعات فضای کاری محلی، صف همگام‌سازی و اسناد است.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'restore'),
                icon: const Icon(Icons.restore_rounded),
                label: const Text('بازیابی پشتیبان'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'create'),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('تهیه پشتیبان'),
              ),
            ],
          ),
        );
    if (action == 'create') {
      final data = await widget.store.createWorkspaceBackup();
      final path = await CrmReportService.saveJsonFile(
        suggestedName: 'sales-crm-backup.json',
        data: data,
      );
      if (mounted && path != null) {
        showCrmNotice(
          context,
          'نسخه پشتیبان با موفقیت ذخیره شد.',
          type: CrmNoticeType.success,
        );
      }
    } else if (action == 'restore') {
      final data = await CrmReportService.pickJsonObject();
      if (data == null || !mounted) return;
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تایید بازیابی'),
              content: const Text(
                'اطلاعات فعلی فضای کاری با محتوای فایل پشتیبان جایگزین می‌شود. ادامه می‌دهید؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('انصراف'),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('بازیابی'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      await widget.store.restoreWorkspaceBackup(data);
      if (mounted) {
        showCrmNotice(
          context,
          'نسخه پشتیبان بازیابی شد.',
          type: CrmNoticeType.success,
        );
      }
    }
  }

  Future<void> _sync() async {
    await widget.store.sync();
    if (!mounted) return;
    showCrmNotice(
      context,
      widget.store.syncMessage,
      type: widget.store.online ? CrmNoticeType.success : CrmNoticeType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filteredCustomers();
    return ListView(
      children: [
        CrmPageHeader(
          title: 'دفترچه مشتریان',
          subtitle:
              'اطلاعات مشتری، وضعیت ارتباط و اولویت فروش را یکجا نگه دارید.',
          actions: [
            PopupMenuButton<String>(
              tooltip: 'ابزار / امکانات',
              onSelected: (value) {
                if (value == 'import') _importExcel();
                if (value == 'export') _exportExcel();
                if (value == 'phonebook') _openPhonebook();
                if (value == 'backup') _backupTools('create');
                if (value == 'restore') _backupTools('restore');
                if (value == 'sync') _sync();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'import',
                  child: Text('ورود اطلاعات از اکسل'),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Text('خروجی اطلاعات به اکسل'),
                ),
                PopupMenuItem(value: 'phonebook', child: Text('دفتر تلفن')),
                PopupMenuItem(value: 'backup', child: Text('تهیه پشتیبان')),
                PopupMenuItem(value: 'restore', child: Text('بازیابی پشتیبان')),
                PopupMenuItem(value: 'sync', child: Text('همگام‌سازی')),
              ],
              child: IgnorePointer(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.handyman_outlined),
                  label: const Text('ابزار / امکانات'),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('مشتری جدید'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CrmPageToolbar(
          onNew: _openEditor,
          onReport: _openPhonebook,
          onExportExcel: _exportExcel,
          onImportExcel: _importExcel,
          onTools: _backupTools,
          onRefresh: widget.store.refresh,
          onSearch: () => setState(() {}),
          onAdvancedFilter: () => setState(() {}),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'فیلتر هر ستون',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...const [
                'مشتری جدید',
                'مشتری VIP',
                'بدون تماس ۱۵ تا ۲۰ روز',
                'بدون تماس ۲۰ تا ۳۰ روز',
                'بدون خرید',
                'بدون فروش',
                'فرصت فعال',
                'فرصت منقضی',
                'اولویت بالا',
              ].map(
                (filter) => ChoiceChip(
                  selected: _quickFilter == filter,
                  label: Text(filter),
                  onSelected: (selected) =>
                      setState(() => _quickFilter = selected ? filter : null),
                ),
              ),
              _filterText(_search, 'جست‌وجوی سراسری', Icons.search_rounded),
              _filterText(_codeFilter, 'کد مشتری', Icons.numbers_rounded),
              _filterText(_nameFilter, 'نام / شرکت', Icons.person_outline),
              _filterText(_mobileFilter, 'موبایل', Icons.phone_android),
              _filterText(_cityFilter, 'شهر', Icons.location_city_outlined),
              _filterDropdown(
                'نوع فعالیت',
                _activityFilter,
                widget.store.activityTypes,
                (value) => setState(() => _activityFilter = value),
              ),
              _filterDropdown(
                'وضعیت',
                _statusFilter,
                widget.store.customerStatuses,
                (value) => setState(() => _statusFilter = value),
              ),
              _filterDropdown(
                'اولویت',
                _priorityFilter,
                widget.store.customerPriorities,
                (value) => setState(() => _priorityFilter = value),
              ),
              _filterDropdown(
                'استان',
                _provinceFilter,
                widget.store.customers
                    .map((item) => item.province)
                    .where((item) => item.isNotEmpty)
                    .toSet()
                    .toList(),
                (value) => setState(() => _provinceFilter = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (rows.isEmpty)
          const SectionCard(
            title: 'مشتریان',
            child: EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'موردی پیدا نشد',
              message: 'عبارت جست‌وجو را تغییر دهید یا مشتری جدیدی اضافه کنید.',
            ),
          )
        else
          SectionCard(
            title: 'فهرست مشتریان',
            trailing: Text(
              rows.length.toString() + ' مشتری',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: CrmConfigurableDataTable<CrmCustomer>(
              tableId: 'customers',
              rows: rows,
              initialSortColumnId: 'code',
              columns: [
                CrmTableColumn(
                  id: 'code',
                  label: 'کد مشتری',
                  value: (item) => item.customerCode,
                ),
                CrmTableColumn(
                  id: 'name',
                  label: 'نام مخاطب',
                  value: (item) => item.name,
                ),
                CrmTableColumn(
                  id: 'company',
                  label: 'شرکت',
                  value: (item) => item.company,
                ),
                CrmTableColumn(
                  id: 'mobile',
                  label: 'موبایل',
                  value: (item) => item.mobile,
                ),
                CrmTableColumn(
                  id: 'phone',
                  label: 'تلفن',
                  value: (item) => item.phone,
                ),
                CrmTableColumn(
                  id: 'email',
                  label: 'ایمیل',
                  value: (item) => item.details['email'] ?? '',
                  initiallyVisible: false,
                ),
                CrmTableColumn(
                  id: 'province',
                  label: 'استان',
                  value: (item) => item.province,
                ),
                CrmTableColumn(
                  id: 'city',
                  label: 'شهر',
                  value: (item) => item.city,
                ),
                CrmTableColumn(
                  id: 'activity',
                  label: 'نوع فعالیت',
                  value: (item) => item.activityType,
                ),
                CrmTableColumn(
                  id: 'status',
                  label: 'وضعیت',
                  value: (item) => item.status,
                  cell: (context, item) => StatusPill(label: item.status),
                ),
                CrmTableColumn(
                  id: 'priority',
                  label: 'اولویت',
                  value: (item) => item.priority,
                ),
                CrmTableColumn(
                  id: 'vip',
                  label: 'VIP',
                  value: (item) => item.isVip ? 'بله' : 'خیر',
                  cell: (context, item) => Icon(
                    item.isVip ? Icons.workspace_premium_rounded : Icons.remove,
                    color: item.isVip ? const Color(0xffe58a00) : null,
                  ),
                ),
                CrmTableColumn(
                  id: 'tags',
                  label: 'برچسب‌ها',
                  value: (item) => item.tags.join('، '),
                  initiallyVisible: false,
                ),
                CrmTableColumn(
                  id: 'address',
                  label: 'آدرس',
                  value: (item) => item.details['address'] ?? '',
                  initiallyVisible: false,
                ),
                CrmTableColumn(
                  id: 'notes',
                  label: 'یادداشت',
                  value: (item) => item.notes,
                  initiallyVisible: false,
                ),
                CrmTableColumn(
                  id: 'actions',
                  label: 'عملیات',
                  value: (_) => '',
                  filterable: false,
                  canHide: false,
                  cell: (context, customer) => PopupMenuButton<String>(
                    tooltip: 'عملیات مشتری',
                    onSelected: (value) {
                      if (value == 'view') _showDetails(customer);
                      if (value == 'edit') _openEditor(customer);
                      if (value == 'note') _openEditor(customer);
                      if (value == 'call') _newCall(customer);
                      if (value == 'quote') _newQuote(customer);
                      if (value == 'order') _newOrder(customer);
                      if (value == 'print') _openPhonebook([customer]);
                      if (value == 'attachments') {
                        showCrmAttachmentManager(
                          context,
                          store: widget.store,
                          entityType: 'customer',
                          entityId: customer.id,
                          title: customer.displayName,
                        );
                      }
                      if (value == 'history') {
                        showCrmAuditLog(
                          context,
                          store: widget.store,
                          entityType: 'customer',
                          entityId: customer.id,
                          title: customer.displayName,
                        );
                      }
                      if (value == 'delete') _delete(customer);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('مشاهده')),
                      PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                      PopupMenuItem(value: 'note', child: Text('یادداشت')),
                      PopupMenuItem(
                        value: 'call',
                        child: Text('ثبت تماس جدید'),
                      ),
                      PopupMenuItem(value: 'quote', child: Text('پیش‌فاکتور')),
                      PopupMenuItem(value: 'order', child: Text('سفارش')),
                      PopupMenuItem(value: 'print', child: Text('گزارش و چاپ')),
                      PopupMenuItem(
                        value: 'attachments',
                        child: Text('فایل‌های پیوست'),
                      ),
                      PopupMenuItem(
                        value: 'history',
                        child: Text('تاریخچه تغییرات'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filterText(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => SizedBox(
    width: 190,
    child: TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );

  Widget _filterDropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('همه')),
        ...values.toSet().map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
      onChanged: changed,
    ),
  );
}

class _CustomerTimelineEvent {
  const _CustomerTimelineEvent({
    required this.date,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final DateTime date;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _CustomerDetailsDialog extends StatefulWidget {
  const _CustomerDetailsDialog({required this.store, required this.customer});

  final CrmStore store;
  final CrmCustomer customer;

  @override
  State<_CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<_CustomerDetailsDialog> {
  List<_CustomerTimelineEvent> get _events {
    final customer = widget.customer;
    final result = <_CustomerTimelineEvent>[
      if (customer.notes.trim().isNotEmpty)
        _CustomerTimelineEvent(
          date: customer.updatedAt,
          icon: Icons.sticky_note_2_outlined,
          title: 'یادداشت مشتری',
          subtitle: customer.notes,
          color: Colors.amber,
        ),
      ...widget.store.calls
          .where((item) => item.customerId == customer.id)
          .map(
            (item) => _CustomerTimelineEvent(
              date: item.callAt,
              icon: item.type == 'جلسه'
                  ? Icons.groups_outlined
                  : Icons.phone_in_talk_outlined,
              title: item.type == 'جلسه' ? 'جلسه' : 'تماس',
              subtitle: '${item.subject} — ${item.status}',
              color: Colors.blue,
            ),
          ),
      ...widget.store.opportunities
          .where((item) => item.customerId == customer.id)
          .map(
            (item) => _CustomerTimelineEvent(
              date: item.updatedAt,
              icon: Icons.track_changes_outlined,
              title: 'فرصت ${item.tradeType}',
              subtitle: '${item.title} — ${item.stage}',
              color: Colors.purple,
            ),
          ),
      ...widget.store.quotes
          .where((item) => item.customerId == customer.id)
          .map(
            (item) => _CustomerTimelineEvent(
              date: item.updatedAt,
              icon: Icons.request_quote_outlined,
              title: 'پیش‌فاکتور ${item.quoteNumber}',
              subtitle: '${item.status} — ${compactMoney(item.totalAmount)}',
              color: Colors.teal,
            ),
          ),
      ...widget.store.orders
          .where((item) => item.customerId == customer.id)
          .map(
            (item) => _CustomerTimelineEvent(
              date: item.orderAt,
              icon: item.status.contains('فاکتور')
                  ? Icons.receipt_long_outlined
                  : Icons.shopping_cart_outlined,
              title: item.status.contains('فاکتور')
                  ? 'فاکتور ${item.orderNumber}'
                  : 'سفارش ${item.orderNumber}',
              subtitle: '${item.status} — ${compactMoney(item.totalAmount)}',
              color: Colors.green,
            ),
          ),
      ...widget.store.tasks
          .where((item) => item.customerId == customer.id)
          .map(
            (item) => _CustomerTimelineEvent(
              date: item.updatedAt,
              icon: Icons.note_alt_outlined,
              title: item.taskType,
              subtitle: '${item.title} — ${item.status}',
              color: Colors.orange,
            ),
          ),
      ...widget.store
          .attachmentsFor('customer', customer.id)
          .map(
            (item) => _CustomerTimelineEvent(
              date: item.updatedAt,
              icon: Icons.attach_file_rounded,
              title: 'فایل پیوست',
              subtitle: item.fileName,
              color: Colors.blueGrey,
            ),
          ),
    ];
    result.sort((left, right) => right.date.compareTo(left.date));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final attachments = widget.store.attachmentsFor('customer', customer.id);
    final audits = widget.store.auditFor('customer', customer.id);
    return DefaultTabController(
      length: 4,
      child: AlertDialog(
        title: Text('پرونده مشتری — ${customer.displayName}'),
        content: SizedBox(
          width: 900,
          height: 620,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'مشخصات', icon: Icon(Icons.badge_outlined)),
                  Tab(text: 'سوابق فعالیت', icon: Icon(Icons.timeline_rounded)),
                  Tab(text: 'پیوست‌ها', icon: Icon(Icons.attach_file_rounded)),
                  Tab(text: 'تاریخچه', icon: Icon(Icons.history_rounded)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _detailsGrid(customer),
                        if (customer.notes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('یادداشت: ${customer.notes}'),
                        ],
                      ],
                    ),
                    _events.isEmpty
                        ? const EmptyState(
                            icon: Icons.timeline_rounded,
                            title: 'سابقه‌ای وجود ندارد',
                            message:
                                'تماس، جلسه یا سند بعدی اینجا نمایش داده می‌شود.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _events.length,
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 42,
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 17,
                                            backgroundColor: event.color
                                                .withValues(alpha: 0.14),
                                            child: Icon(
                                              event.icon,
                                              size: 18,
                                              color: event.color,
                                            ),
                                          ),
                                          if (index < _events.length - 1)
                                            Expanded(
                                              child: VerticalDivider(
                                                color: event.color.withValues(
                                                  alpha: 0.35,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListTile(
                                        title: Text(event.title),
                                        subtitle: Text(event.subtitle),
                                        trailing: Text(
                                          formatJalaliDate(
                                            event.date,
                                            includeTime: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: FilledButton.icon(
                            onPressed: () async {
                              await showCrmAttachmentManager(
                                context,
                                store: widget.store,
                                entityType: 'customer',
                                entityId: customer.id,
                                title: customer.displayName,
                              );
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.attach_file_rounded),
                            label: const Text('مدیریت فایل‌های پیوست'),
                          ),
                        ),
                        Expanded(
                          child: attachments.isEmpty
                              ? const Center(child: Text('فایلی ثبت نشده است.'))
                              : ListView(
                                  children: attachments
                                      .map(
                                        (item) => ListTile(
                                          leading: const Icon(
                                            Icons.insert_drive_file_outlined,
                                          ),
                                          title: Text(item.fileName),
                                          subtitle: Text(item.uploadedBy),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            onPressed: () => showCrmAuditLog(
                              context,
                              store: widget.store,
                              entityType: 'customer',
                              entityId: customer.id,
                              title: customer.displayName,
                            ),
                            icon: const Icon(Icons.manage_history_rounded),
                            label: const Text('نمایش مقادیر قبلی و جدید'),
                          ),
                        ),
                        Expanded(
                          child: audits.isEmpty
                              ? const Center(
                                  child: Text('تغییری ثبت نشده است.'),
                                )
                              : ListView(
                                  children: audits
                                      .map(
                                        (item) => ListTile(
                                          leading: const Icon(Icons.history),
                                          title: Text(item.action),
                                          subtitle: Text(item.userName),
                                          trailing: Text(
                                            formatJalaliDate(
                                              item.updatedAt,
                                              includeTime: true,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _detailsGrid(CrmCustomer customer) {
    final entries = <String, String>{
      'کد مشتری': customer.customerCode,
      'نام مخاطب': customer.name,
      'شرکت': customer.company,
      'موبایل': customer.mobile,
      'تلفن': customer.phone,
      'ایمیل': customer.details['email'] ?? '',
      'استان': customer.province,
      'شهر': customer.city,
      'نوع فعالیت': customer.activityType,
      'وضعیت': customer.status,
      'اولویت': customer.priority,
      'آدرس': customer.details['address'] ?? '',
      'برچسب‌ها': customer.tags.join('، '),
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries.entries
          .map(
            (entry) => SizedBox(
              width: 260,
              child: ListTile(
                tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(entry.key),
                subtitle: SelectableText(
                  entry.value.trim().isEmpty ? '—' : entry.value,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({required this.store, this.customer});

  final CrmStore store;
  final CrmCustomer? customer;

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

enum _CustomerOptionKind { activity, status, priority }

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerCode = TextEditingController();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _mobile = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _secondaryMobile = TextEditingController();
  final _nationalId = TextEditingController();
  final _province = TextEditingController(text: 'تهران');
  final _city = TextEditingController(text: 'تهران');
  final _district = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _source = TextEditingController();
  final _interestedProducts = TextEditingController();
  final _monthlyVolume = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _fax = TextEditingController();
  final _website = TextEditingController();
  final _notes = TextEditingController();
  final _tags = TextEditingController();
  String _activity = 'تولیدکننده';
  String _status = 'فعال';
  String _priority = 'متوسط';
  bool _isVip = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    if (customer == null) {
      _customerCode.text = widget.store.nextCustomerCode();
      return;
    }
    _customerCode.text = customer.customerCode.isEmpty
        ? widget.store.nextCustomerCode()
        : customer.customerCode;
    _name.text = customer.name;
    _company.text = customer.company;
    _mobile.text = formatPersianDigitsOnly(customer.mobile);
    _phone.text = formatPersianDigitsOnly(customer.phone);
    _province.text = customer.province;
    _city.text = customer.city;
    _activity = customer.activityType;
    _status = customer.status;
    _priority = customer.priority;
    _notes.text = customer.notes;
    _tags.text = customer.tags.join('، ');
    _isVip = customer.isVip;
    final details = customer.details;
    _email.text = details['email'] ?? '';
    _secondaryMobile.text = formatPersianDigitsOnly(
      details['secondary_mobile'] ?? '',
    );
    _nationalId.text = formatPersianDigitsOnly(details['national_id'] ?? '');
    _district.text = details['district'] ?? '';
    _address.text = details['address'] ?? '';
    _postalCode.text = formatPersianDigitsOnly(details['postal_code'] ?? '');
    _source.text = details['source'] ?? '';
    _interestedProducts.text = details['interested_products'] ?? '';
    _monthlyVolume.text = formatPersianDigitsOnly(
      details['monthly_volume'] ?? '',
    );
    _paymentTerms.text = details['payment_terms'] ?? '';
    _fax.text = formatPersianDigitsOnly(details['fax'] ?? '');
    _website.text = details['website'] ?? '';
  }

  @override
  void dispose() {
    _customerCode.dispose();
    _name.dispose();
    _company.dispose();
    _mobile.dispose();
    _phone.dispose();
    _email.dispose();
    _secondaryMobile.dispose();
    _nationalId.dispose();
    _province.dispose();
    _city.dispose();
    _district.dispose();
    _address.dispose();
    _postalCode.dispose();
    _source.dispose();
    _interestedProducts.dispose();
    _monthlyVolume.dispose();
    _paymentTerms.dispose();
    _fax.dispose();
    _website.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
    });
    await widget.store.saveCustomer(
      name: _name.text,
      company: _company.text,
      mobile: formatPersianDigitsOnly(_mobile.text),
      phone: formatPersianDigitsOnly(_phone.text),
      province: _province.text,
      city: _city.text,
      activityType: _activity,
      status: _status,
      priority: _priority,
      notes: _notes.text,
      tags: _tags.text
          .split(RegExp(r'[,،]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      details: {
        ...?widget.customer?.details,
        'customer_code': _customerCode.text.trim(),
        'is_vip': _isVip ? 'true' : 'false',
        'email': _email.text.trim(),
        'secondary_mobile': formatPersianDigitsOnly(_secondaryMobile.text),
        'national_id': formatPersianDigitsOnly(_nationalId.text),
        'district': _district.text.trim(),
        'address': _address.text.trim(),
        'postal_code': formatPersianDigitsOnly(_postalCode.text),
        'source': _source.text.trim(),
        'interested_products': _interestedProducts.text.trim(),
        'monthly_volume': formatPersianDigitsOnly(_monthlyVolume.text),
        'payment_terms': _paymentTerms.text.trim(),
        'fax': formatPersianDigitsOnly(_fax.text),
        'website': _website.text.trim(),
      },
      id: widget.customer?.id,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'ثبت مشتری جدید' : 'ویرایش مشتری'),
      content: CrmDialogContent(
        maxWidth: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: ResponsiveFormGrid(
              children: [
                _input(
                  _customerCode,
                  TextFormField(
                    controller: _customerCode,
                    decoration: const InputDecoration(
                      labelText: 'کد مشتری *',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.isEmpty) return 'کد مشتری الزامی است.';
                      final duplicate = widget.store.customers.any(
                        (item) =>
                            item.id != widget.customer?.id &&
                            item.customerCode.toLowerCase() ==
                                code.toLowerCase(),
                      );
                      return duplicate
                          ? 'این کد مشتری قبلاً ثبت شده است.'
                          : null;
                    },
                  ),
                ),
                ResponsiveFormField(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isVip,
                    title: const Text('مشتری VIP'),
                    subtitle: const Text(
                      'نمایش در فهرست ویژه و پیگیری‌های اولویت‌دار',
                    ),
                    onChanged: (value) => setState(() => _isVip = value),
                  ),
                ),
                _input(
                  _name,
                  TextFormField(
                    controller: _name,
                    inputFormatters: [textOnlyFormatter],
                    decoration: const InputDecoration(
                      labelText: 'نام مخاطب *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'نام مخاطب الزامی است.'
                        : null,
                  ),
                ),
                _input(
                  _company,
                  TextFormField(
                    controller: _company,
                    inputFormatters: [textOnlyFormatter],
                    decoration: const InputDecoration(
                      labelText: 'نام شرکت',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                ),
                _input(
                  _mobile,
                  TextFormField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'شماره موبایل *',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'شماره موبایل الزامی است.'
                        : null,
                  ),
                ),
                _input(
                  _phone,
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'تلفن ثابت',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                _input(
                  _email,
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ),
                _input(
                  _secondaryMobile,
                  TextFormField(
                    controller: _secondaryMobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'تلفن همراه دوم',
                      prefixIcon: Icon(Icons.phone_iphone_outlined),
                    ),
                  ),
                ),
                _input(
                  _nationalId,
                  TextFormField(
                    controller: _nationalId,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'کد ملی / شناسه ملی',
                    ),
                  ),
                ),
                _input(
                  _province,
                  TextFormField(
                    controller: _province,
                    decoration: const InputDecoration(labelText: 'استان'),
                  ),
                ),
                _input(
                  _city,
                  TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'شهر'),
                  ),
                ),
                _wideField(
                  DropdownButtonFormField<String>(
                    initialValue: _activity,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'نوع فعالیت',
                      suffixIcon: IconButton(
                        tooltip: 'مدیریت نوع فعالیت',
                        onPressed: () =>
                            _manageOptions(_CustomerOptionKind.activity),
                        icon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    items: {...widget.store.activityTypes, _activity}
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _activity = value ?? _activity;
                      });
                    },
                  ),
                ),
                _wideField(
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'وضعیت مشتری',
                      suffixIcon: IconButton(
                        tooltip: 'مدیریت وضعیت مشتری',
                        onPressed: () =>
                            _manageOptions(_CustomerOptionKind.status),
                        icon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    items: {...widget.store.customerStatuses, _status}
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _status = value ?? _status;
                      });
                    },
                  ),
                ),
                _wideField(
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: InputDecoration(
                      labelText: 'اولویت',
                      suffixIcon: IconButton(
                        tooltip: 'مدیریت اولویت‌ها',
                        onPressed: () =>
                            _manageOptions(_CustomerOptionKind.priority),
                        icon: const Icon(Icons.edit_note_rounded),
                      ),
                    ),
                    items: {...widget.store.customerPriorities, _priority}
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _priority = value ?? _priority;
                      });
                    },
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _tags,
                    child: TextFormField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: 'برچسب‌ها / دسته‌های مشتری',
                        hintText: 'مثلاً عمده‌فروش، تهران، پیگیری ویژه',
                      ),
                    ),
                  ),
                ),
                ResponsiveFormField.full(
                  child: Text(
                    'اطلاعات کسب‌وکار و آدرس',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _input(
                  _source,
                  TextFormField(
                    controller: _source,
                    decoration: const InputDecoration(labelText: 'منبع آشنایی'),
                  ),
                ),
                _input(
                  _interestedProducts,
                  TextFormField(
                    controller: _interestedProducts,
                    decoration: const InputDecoration(
                      labelText: 'کالاها / خدمات مورد علاقه',
                    ),
                  ),
                ),
                _input(
                  _monthlyVolume,
                  TextFormField(
                    controller: _monthlyVolume,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(
                      labelText: 'حدود تناژ / حجم ماهانه',
                    ),
                  ),
                ),
                _input(
                  _paymentTerms,
                  TextFormField(
                    controller: _paymentTerms,
                    decoration: const InputDecoration(
                      labelText: 'شرایط پرداخت',
                    ),
                  ),
                ),
                _input(
                  _district,
                  TextFormField(
                    controller: _district,
                    decoration: const InputDecoration(
                      labelText: 'منطقه / خیابان',
                    ),
                  ),
                ),
                _input(
                  _postalCode,
                  TextFormField(
                    controller: _postalCode,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(labelText: 'کد پستی'),
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _address,
                    child: TextFormField(
                      controller: _address,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'آدرس کامل',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ),
                _input(
                  _fax,
                  TextFormField(
                    controller: _fax,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [persianNumberFormatter],
                    decoration: const InputDecoration(labelText: 'فکس'),
                  ),
                ),
                _input(
                  _website,
                  TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'وب‌سایت'),
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _notes,
                    child: TextFormField(
                      controller: _notes,
                      minLines: 3,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'یادداشت',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('ذخیره'),
        ),
      ],
    );
  }

  Widget _wideField(Widget child) => child;

  Future<void> _manageOptions(_CustomerOptionKind kind) async {
    var items = switch (kind) {
      _CustomerOptionKind.activity => [...widget.store.activityTypes],
      _CustomerOptionKind.status => [...widget.store.customerStatuses],
      _CustomerOptionKind.priority => [...widget.store.customerPriorities],
    };
    final label = switch (kind) {
      _CustomerOptionKind.activity => 'نوع فعالیت',
      _CustomerOptionKind.status => 'وضعیت مشتری',
      _CustomerOptionKind.priority => 'اولویت',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('مدیریت $label'),
          content: SizedBox(
            width: 460,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final value = await _promptOption('افزودن $label');
                    if (value == null || value.trim().isEmpty) return;
                    await _addManagedOption(kind, value);
                    setDialogState(
                      () => items = switch (kind) {
                        _CustomerOptionKind.activity => [
                          ...widget.store.activityTypes,
                        ],
                        _CustomerOptionKind.status => [
                          ...widget.store.customerStatuses,
                        ],
                        _CustomerOptionKind.priority => [
                          ...widget.store.customerPriorities,
                        ],
                      },
                    );
                    if (mounted) _selectOption(kind, value.trim());
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text('افزودن $label'),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(item),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'ویرایش',
                              onPressed: () async {
                                final value = await _promptOption(
                                  'ویرایش $label',
                                  initialValue: item,
                                );
                                if (value == null || value.trim().isEmpty) {
                                  return;
                                }
                                await _renameManagedOption(kind, item, value);
                                setDialogState(() {
                                  items[index] = value.trim();
                                });
                                if (mounted && _selectedOption(kind) == item) {
                                  _selectOption(kind, value.trim());
                                }
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              onPressed: items.length <= 1
                                  ? null
                                  : () async {
                                      await _removeManagedOption(kind, item);
                                      setDialogState(
                                        () => items.removeAt(index),
                                      );
                                      if (mounted &&
                                          _selectedOption(kind) == item) {
                                        _selectOption(kind, items.first);
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptOption(
    String title, {
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'عنوان'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  String _selectedOption(_CustomerOptionKind kind) => switch (kind) {
    _CustomerOptionKind.activity => _activity,
    _CustomerOptionKind.status => _status,
    _CustomerOptionKind.priority => _priority,
  };

  void _selectOption(_CustomerOptionKind kind, String value) => setState(() {
    switch (kind) {
      case _CustomerOptionKind.activity:
        _activity = value;
      case _CustomerOptionKind.status:
        _status = value;
      case _CustomerOptionKind.priority:
        _priority = value;
    }
  });

  Future<void> _addManagedOption(_CustomerOptionKind kind, String value) =>
      switch (kind) {
        _CustomerOptionKind.activity => widget.store.addActivityType(value),
        _CustomerOptionKind.status => widget.store.addCustomerStatus(value),
        _CustomerOptionKind.priority => widget.store.addCustomerPriority(value),
      };

  Future<void> _renameManagedOption(
    _CustomerOptionKind kind,
    String oldValue,
    String newValue,
  ) => switch (kind) {
    _CustomerOptionKind.activity => widget.store.renameActivityType(
      oldValue,
      newValue,
    ),
    _CustomerOptionKind.status => widget.store.renameCustomerStatus(
      oldValue,
      newValue,
    ),
    _CustomerOptionKind.priority => widget.store.renameCustomerPriority(
      oldValue,
      newValue,
    ),
  };

  Future<void> _removeManagedOption(_CustomerOptionKind kind, String value) =>
      switch (kind) {
        _CustomerOptionKind.activity => widget.store.removeActivityType(value),
        _CustomerOptionKind.status => widget.store.removeCustomerStatus(value),
        _CustomerOptionKind.priority => widget.store.removeCustomerPriority(
          value,
        ),
      };

  Widget _input(TextEditingController controller, Widget child) {
    return _wideField(AutoInputDirection(controller: controller, child: child));
  }
}
