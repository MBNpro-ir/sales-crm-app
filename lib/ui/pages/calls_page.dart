import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';
import 'documents_page.dart';

Future<bool?> showCrmCallEditor(
  BuildContext context, {
  required CrmStore store,
  CrmCall? call,
  String? initialCustomerId,
  VoidCallback? onOpenProducts,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _CallEditorDialog(
      store: store,
      call: call,
      initialCustomerId: initialCustomerId,
      onOpenProducts: onOpenProducts,
    ),
  );
}

class CallsPage extends StatefulWidget {
  const CallsPage({
    super.key,
    required this.store,
    this.initialStatus,
    this.initialCustomerId,
    this.openEditorOnStart = false,
    this.onOpenProducts,
  });

  final CrmStore store;
  final String? initialStatus;
  final String? initialCustomerId;
  final bool openEditorOnStart;
  final VoidCallback? onOpenProducts;

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  final _search = TextEditingController();
  String? _resultFilter;
  String? _typeFilter;
  String? _tradeFilter;
  String? _activityFilter;
  String? _priorityFilter;
  String _groupBy = 'نتیجه تماس';
  bool _vipOnly = false;

  @override
  void initState() {
    super.initState();
    _resultFilter = widget.initialStatus;
    if (widget.openEditorOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditor(null, widget.initialCustomerId);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor([CrmCall? call, String? customerId]) async {
    if (widget.store.customers.isEmpty) {
      showCrmNotice(
        context,
        'ابتدا یک مشتری ثبت کنید.',
        type: CrmNoticeType.warning,
      );
      return;
    }
    final saved = await showCrmCallEditor(
      context,
      store: widget.store,
      call: call,
      initialCustomerId: customerId,
      onOpenProducts: widget.onOpenProducts,
    );
    if (!mounted || saved != true) return;
    showCrmNotice(
      context,
      call == null ? 'تماس ثبت و برای همگام‌سازی صف شد.' : 'تماس ویرایش شد.',
      type: CrmNoticeType.success,
    );
  }

  Future<void> _delete(CrmCall call) async {
    if (!await confirmDelete(context, label: call.subject)) return;
    await widget.store.deleteCall(call);
    if (mounted) {
      showCrmNotice(
        context,
        'تماس حذف و با سرور همگام‌سازی شد.',
        type: CrmNoticeType.warning,
      );
    }
  }

  CrmCustomer? _customerFor(CrmCall call) => widget.store.customers
      .cast<CrmCustomer?>()
      .firstWhere((item) => item?.id == call.customerId, orElse: () => null);

  List<CrmCustomer> _staleCustomers() {
    final threshold = DateTime.now().subtract(const Duration(days: 15));
    return widget.store.customers.where((customer) {
      final calls = widget.store.calls
          .where((call) => call.customerId == customer.id)
          .toList();
      if (calls.isEmpty) return true;
      calls.sort((a, b) => b.callAt.compareTo(a.callAt));
      return calls.first.callAt.isBefore(threshold);
    }).toList();
  }

  static const _excelHeaders = [
    'شناسه',
    'کد مشتری',
    'مشتری',
    'موضوع تماس',
    'نوع تماس',
    'جهت تماس',
    'نتیجه',
    'خرید / فروش',
    'کالا / خدمت',
    'تعداد / تناژ',
    'فی',
    'مبلغ پایه',
    'تخفیف ریالی',
    'ارزش افزوده (درصد)',
    'ارزش افزوده (ریال)',
    'جمع کل',
    'مدت (دقیقه)',
    'تاریخ و زمان',
    'استان',
    'شهر',
    'شرح',
  ];

  List<List<Object?>> _rowsForCalls(List<CrmCall> calls) =>
      calls.asMap().entries.map((entry) {
        final item = entry.value;
        final customer = _customerFor(item);
        return <Object?>[
          item.id,
          customer?.customerCode ?? '',
          item.customerName,
          item.subject,
          item.type,
          item.direction,
          item.status,
          item.tradeType,
          item.productName,
          item.quantity,
          item.unitPrice,
          item.subtotal,
          item.discountAmount,
          item.taxPercent,
          item.taxAmount,
          item.totalAmount,
          item.durationMinutes,
          item.callAt.toUtc().toIso8601String(),
          customer?.province ?? '',
          customer?.city ?? '',
          item.notes,
        ];
      }).toList();

  Future<void> _printCalls() {
    final calls = _filteredCalls();
    final rows = calls.asMap().entries.map((entry) {
      final item = entry.value;
      final customer = _customerFor(item);
      return <Object?>[
        entry.key + 1,
        item.customerName,
        item.subject,
        item.type,
        item.status,
        item.hasTradeOutcome ? r'$' : '',
        item.tradeType,
        item.productName,
        customer?.province ?? '',
        customer?.city ?? '',
        item.subtotal,
        item.discountAmount,
        item.taxAmount,
        item.totalAmount,
        formatJalaliDate(item.callAt, includeTime: true),
      ];
    }).toList();
    return CrmReportService.printTable(
      context: context,
      title: 'گزارش تماس‌ها و جلسات',
      subtitle:
          'گزارش عملکرد قابل تنظیم بر اساس بازه تاریخ، مشتری، کالا، شهر و استان',
      headers: const [
        'ردیف',
        'مشتری',
        'موضوع',
        'نوع',
        'نتیجه',
        'معامله',
        'خرید/فروش',
        'کالا / خدمت',
        'استان',
        'شهر',
        'مبلغ پایه',
        'تخفیف',
        'ارزش افزوده',
        'جمع کل',
        'تاریخ و زمان',
      ],
      rows: rows,
      rowDates: calls.map((item) => item.callAt).toList(),
      numericColumns: const {10, 11, 12, 13},
    );
  }

  Future<void> _exportExcel() async {
    final path = await CrmReportService.exportExcel(
      suggestedName: 'calls.xlsx',
      sheetName: 'تماس‌ها',
      headers: _excelHeaders,
      rows: _rowsForCalls(_filteredCalls()),
    );
    if (mounted && path != null) {
      showCrmNotice(
        context,
        'خروجی اکسل تماس‌ها ذخیره شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  Future<void> _importExcel() async {
    final table = await CrmReportService.pickExcelRows();
    if (table == null || table.isEmpty) return;
    const aliases = <String, String>{
      'شناسه': 'id',
      'کد مشتری': 'customer_code',
      'مشتری': 'customer_name',
      'موضوع تماس': 'subject',
      'نوع تماس': 'type',
      'جهت تماس': 'direction',
      'نتیجه': 'status',
      'خرید / فروش': 'trade_type',
      'کالا / خدمت': 'product_name',
      'تعداد / تناژ': 'quantity',
      'فی': 'unit_price',
      'مبلغ پایه': 'amount',
      'تخفیف ریالی': 'discount_amount',
      'ارزش افزوده (درصد)': 'tax_percent',
      'مدت (دقیقه)': 'duration_minutes',
      'تاریخ و زمان': 'call_at',
      'شرح': 'notes',
    };
    final headers = table.first.map((item) => aliases[item] ?? '').toList();
    final records = <Map<String, String>>[];
    for (final row in table.skip(1)) {
      final record = <String, String>{};
      for (
        var index = 0;
        index < headers.length && index < row.length;
        index++
      ) {
        if (headers[index].isNotEmpty) record[headers[index]] = row[index];
      }
      records.add(record);
    }
    final count = await widget.store.importCallRows(records);
    if (mounted) {
      showCrmNotice(
        context,
        '${formatPersianInteger(count)} تماس از اکسل ثبت یا به‌روزرسانی شد.',
        type: count == 0 ? CrmNoticeType.warning : CrmNoticeType.success,
      );
    }
  }

  Future<void> _newDocument(CrmCall call, DocumentPageMode mode) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => DocumentEditorDialog(
        store: widget.store,
        mode: mode,
        initialCustomerId: call.customerId,
        initialDirection: call.tradeType == 'خرید' ? 'خرید' : 'فروش',
      ),
    );
    if (mounted && saved == true) {
      showCrmNotice(
        context,
        mode == DocumentPageMode.quote
            ? 'پیش‌فاکتور از روی تماس ثبت شد.'
            : 'سفارش از روی تماس ثبت شد.',
        type: CrmNoticeType.success,
      );
    }
  }

  List<CrmCall> _filteredCalls() {
    final needle = _search.text.trim().toLowerCase();
    return widget.store.calls.where((call) {
      final customer = _customerFor(call);
      return (needle.isEmpty ||
              call.customerName.toLowerCase().contains(needle) ||
              call.subject.toLowerCase().contains(needle) ||
              call.productName.toLowerCase().contains(needle) ||
              call.status.contains(needle)) &&
          (_resultFilter == null || call.status == _resultFilter) &&
          (_typeFilter == null || call.type == _typeFilter) &&
          (_tradeFilter == null || call.tradeType == _tradeFilter) &&
          (_activityFilter == null ||
              customer?.activityType == _activityFilter) &&
          (_priorityFilter == null || customer?.priority == _priorityFilter) &&
          (!_vipOnly || customer?.isVip == true);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final rows = _filteredCalls();
    final failed = store.calls.where((call) => call.status == 'ناموفق').length;
    return ListView(
      children: [
        CrmPageHeader(
          title: 'مدیریت تماس‌ها',
          subtitle: 'تماس‌ها، نتیجه، مبلغ احتمالی و پیگیری بعدی را ثبت کنید.',
          actions: [
            PopupMenuButton<String>(
              tooltip: 'ورود و خروج اکسل',
              onSelected: (value) {
                if (value == 'import') _importExcel();
                if (value == 'export') _exportExcel();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'import',
                  child: Text('ورود اطلاعات از اکسل'),
                ),
                PopupMenuItem(value: 'export', child: Text('خروجی از اکسل')),
              ],
              child: IgnorePointer(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('ابزار اکسل'),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _printCalls,
              icon: const Icon(Icons.print_outlined),
              label: const Text('گزارش و چاپ'),
            ),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_call),
              label: const Text('ثبت تماس جدید'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'کل تماس‌ها',
                value: store.calls.length.toString(),
                icon: Icons.phone_in_talk_rounded,
                color: const Color(0xff0b63ce),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'تماس موفق',
                value: store.successfulCalls.toString(),
                icon: Icons.phone_enabled_rounded,
                color: const Color(0xff12966b),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'نیازمند پیگیری',
                value: store.followUpCalls.toString(),
                icon: Icons.autorenew_rounded,
                color: const Color(0xffe58a00),
              ),
            ),
            SizedBox(
              width: 240,
              child: KpiCard(
                title: 'تماس ناموفق',
                value: failed.toString(),
                icon: Icons.phone_missed_rounded,
                color: const Color(0xffd84b4b),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_staleCustomers().isNotEmpty) ...[
          SectionCard(
            title: 'هشدار پیگیری؛ بیش از ۱۵ روز بدون تماس',
            trailing: Text(
              '${formatPersianInteger(_staleCustomers().length)} مشتری',
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _staleCustomers()
                  .map(
                    (customer) => ActionChip(
                      avatar: Icon(
                        customer.isVip
                            ? Icons.workspace_premium_rounded
                            : Icons.notification_important_outlined,
                        size: 18,
                      ),
                      label: Text(customer.displayName),
                      onPressed: () => _openEditor(null, customer.id),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
        ],
        SectionCard(
          title: 'گزارش تحلیلی تماس‌ها',
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: const ['موفق', 'پیگیری', 'ناموفق'].map((status) {
              final count = store.calls
                  .where((item) => item.status == status)
                  .length;
              final ratio = store.calls.isEmpty
                  ? 0.0
                  : count / store.calls.length;
              return SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$status: ${formatPersianInteger(count)}'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: ratio),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          title: 'فیلتر هر ستون و دسته‌بندی',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 240,
                child: AutoInputDirection(
                  controller: _search,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'مشتری، موضوع یا کالا',
                    ),
                  ),
                ),
              ),
              _filter(
                'نتیجه تماس',
                _resultFilter,
                const ['موفق', 'پیگیری', 'ناموفق'],
                (value) => setState(() => _resultFilter = value),
              ),
              _filter(
                'نوع تماس',
                _typeFilter,
                const ['تلفنی', 'جلسه', 'استعلام', 'پیام', 'ایمیل'],
                (value) => setState(() => _typeFilter = value),
              ),
              _filter(
                'خرید / فروش',
                _tradeFilter,
                const ['خرید', 'فروش', 'بدون معامله'],
                (value) => setState(() => _tradeFilter = value),
              ),
              _filter(
                'نوع فعالیت',
                _activityFilter,
                store.activityTypes,
                (value) => setState(() => _activityFilter = value),
              ),
              _filter(
                'اولویت مشتری',
                _priorityFilter,
                store.customerPriorities,
                (value) => setState(() => _priorityFilter = value),
              ),
              _filter(
                'دسته‌بندی بر اساس',
                _groupBy,
                const ['نتیجه تماس', 'نوع فعالیت', 'تاریخ', 'اولویت'],
                (value) => setState(() => _groupBy = value ?? _groupBy),
                includeAll: false,
              ),
              FilterChip(
                selected: _vipOnly,
                avatar: const Icon(Icons.workspace_premium_outlined),
                label: const Text('مشتریان VIP'),
                onSelected: (value) => setState(() => _vipOnly = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _groupSummary(rows),
        const SizedBox(height: 18),
        SectionCard(
          title: 'فهرست تماس‌ها',
          trailing: Text('${formatPersianInteger(rows.length)} مورد'),
          padding: const EdgeInsets.all(12),
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.phone_outlined,
                  title: 'تماسی پیدا نشد',
                  message:
                      'عبارت جست‌وجو را تغییر دهید یا تماس جدیدی ثبت کنید.',
                )
              : CrmConfigurableDataTable<CrmCall>(
                  tableId: 'calls',
                  rows: rows,
                  initialSortColumnId: 'date_time',
                  initialSortAscending: false,
                  columns: [
                    CrmTableColumn(
                      id: 'row',
                      label: 'ردیف',
                      value: (item) =>
                          formatPersianInteger(rows.indexOf(item) + 1),
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'customer',
                      label: 'مشتری',
                      value: (item) => item.customerName,
                    ),
                    CrmTableColumn(
                      id: 'subject',
                      label: 'موضوع تماس',
                      value: (item) => item.subject,
                    ),
                    CrmTableColumn(
                      id: 'type',
                      label: 'نوع',
                      value: (item) => item.type,
                    ),
                    CrmTableColumn(
                      id: 'result',
                      label: 'نتیجه',
                      value: (item) => item.status,
                      cell: (context, item) => StatusPill(label: item.status),
                    ),
                    CrmTableColumn(
                      id: 'outcome',
                      label: 'معامله',
                      value: (item) => item.hasTradeOutcome ? 'دلار' : '',
                      cell: (context, item) => Icon(
                        item.hasTradeOutcome
                            ? Icons.attach_money_rounded
                            : Icons.remove,
                        color: item.hasTradeOutcome
                            ? const Color(0xff12966b)
                            : null,
                      ),
                    ),
                    CrmTableColumn(
                      id: 'trade',
                      label: 'خرید / فروش',
                      value: (item) =>
                          item.tradeType.isEmpty ? '—' : item.tradeType,
                    ),
                    CrmTableColumn(
                      id: 'product',
                      label: 'کالا / خدمت',
                      value: (item) =>
                          item.productName.isEmpty ? '—' : item.productName,
                    ),
                    CrmTableColumn(
                      id: 'quantity',
                      label: 'تعداد / تناژ',
                      value: (item) => item.quantity == 0
                          ? '—'
                          : formatPersianInteger(item.quantity),
                      sortValue: (item) => item.quantity,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'date_time',
                      label: 'تاریخ و زمان تماس',
                      value: (item) =>
                          formatJalaliDate(item.callAt, includeTime: true),
                      sortValue: (item) => item.callAt,
                    ),
                    CrmTableColumn(
                      id: 'duration',
                      label: 'مدت',
                      value: (item) =>
                          '${formatPersianInteger(item.durationMinutes)} دقیقه',
                      sortValue: (item) => item.durationMinutes,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'subtotal',
                      label: 'مبلغ پایه',
                      value: (item) => compactMoney(item.subtotal),
                      sortValue: (item) => item.subtotal,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'discount',
                      label: 'تخفیف',
                      value: (item) => compactMoney(item.discountAmount),
                      sortValue: (item) => item.discountAmount,
                      numeric: true,
                      initiallyVisible: false,
                    ),
                    CrmTableColumn(
                      id: 'tax',
                      label: 'ارزش افزوده',
                      value: (item) => compactMoney(item.taxAmount),
                      sortValue: (item) => item.taxAmount,
                      numeric: true,
                      initiallyVisible: false,
                    ),
                    CrmTableColumn(
                      id: 'total',
                      label: 'جمع کل',
                      value: (item) => compactMoney(item.totalAmount),
                      sortValue: (item) => item.totalAmount,
                      numeric: true,
                    ),
                    CrmTableColumn(
                      id: 'actions',
                      label: 'عملیات',
                      value: (_) => '',
                      filterable: false,
                      canHide: false,
                      cell: (context, call) => PopupMenuButton<String>(
                        tooltip: 'عملیات تماس',
                        onSelected: (value) {
                          if (value == 'edit') _openEditor(call);
                          if (value == 'quote') {
                            _newDocument(call, DocumentPageMode.quote);
                          }
                          if (value == 'order') {
                            _newDocument(call, DocumentPageMode.order);
                          }
                          if (value == 'delete') _delete(call);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                          PopupMenuItem(
                            value: 'quote',
                            child: Text('پیش‌فاکتور'),
                          ),
                          PopupMenuItem(value: 'order', child: Text('سفارش')),
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

  Widget _filter(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed, {
    bool includeAll = true,
  }) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (includeAll)
          const DropdownMenuItem<String?>(value: null, child: Text('همه')),
        ...values.map(
          (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
        ),
      ],
      onChanged: changed,
    ),
  );

  Widget _groupSummary(List<CrmCall> calls) {
    final groups = <String, int>{};
    for (final call in calls) {
      final customer = _customerFor(call);
      final key = switch (_groupBy) {
        'نوع فعالیت' => customer?.activityType ?? 'نامشخص',
        'تاریخ' => compactDate(call.callAt),
        'اولویت' => customer?.priority ?? 'نامشخص',
        _ => call.status,
      };
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return SectionCard(
      title: 'دسته‌بندی بر اساس $_groupBy',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: groups.entries
            .map(
              (entry) => Chip(
                label: Text(
                  '${entry.key}: ${formatPersianInteger(entry.value)}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CallEditorDialog extends StatefulWidget {
  const _CallEditorDialog({
    required this.store,
    this.call,
    this.initialCustomerId,
    this.onOpenProducts,
  });

  final CrmStore store;
  final CrmCall? call;
  final String? initialCustomerId;
  final VoidCallback? onOpenProducts;

  @override
  State<_CallEditorDialog> createState() => _CallEditorDialogState();
}

class _CallEditorDialogState extends State<_CallEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _notes = TextEditingController();
  final _duration = TextEditingController(text: '۵');
  final _amount = TextEditingController(text: '۰');
  final _quantity = TextEditingController(text: '۰');
  final _unitPrice = TextEditingController(text: '۰');
  final _discount = TextEditingController(text: '۰');
  final _taxPercent = TextEditingController(text: '۱۰');
  String? _customerId;
  String _productName = '';
  String _type = 'تلفنی';
  String _direction = 'خروجی';
  String _status = 'موفق';
  String _tradeType = 'بدون معامله';
  bool _addFollowUp = true;
  DateTime? _nextFollowUp = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final call = widget.call;
    if (call == null) {
      _customerId = widget.initialCustomerId;
      return;
    }
    _customerId = call.customerId;
    _subject.text = call.subject;
    _notes.text = call.notes;
    _duration.text = formatPersianInteger(call.durationMinutes);
    _amount.text = formatPersianInteger(call.amount, grouping: true);
    _productName = call.productName;
    _quantity.text = formatPersianInteger(call.quantity);
    _unitPrice.text = formatPersianInteger(call.unitPrice, grouping: true);
    _discount.text = formatPersianInteger(call.discountAmount, grouping: true);
    _taxPercent.text = formatPersianInteger(call.taxPercent);
    _type = call.type;
    _direction = call.direction;
    _status = call.status;
    _tradeType = call.tradeType.isEmpty ? 'بدون معامله' : call.tradeType;
    _nextFollowUp = call.nextFollowUp;
    _addFollowUp = call.nextFollowUp != null;
  }

  @override
  void dispose() {
    _subject.dispose();
    _notes.dispose();
    _duration.dispose();
    _amount.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _discount.dispose();
    _taxPercent.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final date = await showCrmJalaliDatePicker(
      context,
      initialDate: _nextFollowUp ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null && mounted) {
      setState(() => _nextFollowUp = date);
    }
  }

  int get _calculatedSubtotal {
    final quantity = parsePersianInt(_quantity.text);
    final unitPrice = parsePersianInt(_unitPrice.text);
    if (quantity > 0 && unitPrice > 0) return quantity * unitPrice;
    return parsePersianInt(_amount.text);
  }

  int get _netAmount => (_calculatedSubtotal - parsePersianInt(_discount.text))
      .clamp(0, 1 << 62)
      .toInt();
  int get _taxAmount =>
      (_netAmount * parsePersianInt(_taxPercent.text) / 100).round();
  int get _totalAmount => _netAmount + _taxAmount;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() => _saving = true);
    final calculatedSubtotal = _calculatedSubtotal;
    await widget.store.saveCall(
      customer: customer,
      subject: _subject.text,
      type: _type,
      direction: _direction,
      status: _status,
      notes: _notes.text,
      durationMinutes: parsePersianInt(_duration.text),
      amount: calculatedSubtotal,
      tradeType: _tradeType,
      productName: _productName,
      quantity: parsePersianInt(_quantity.text),
      unitPrice: parsePersianInt(_unitPrice.text),
      discountAmount: parsePersianInt(_discount.text),
      taxPercent: parsePersianInt(_taxPercent.text),
      nextFollowUp: _addFollowUp ? _nextFollowUp : null,
      id: widget.call?.id,
      callAt: widget.call?.callAt,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.call == null ? 'ثبت و پیگیری تماس' : 'ویرایش تماس'),
      content: CrmDialogContent(
        maxWidth: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: ResponsiveFormGrid(
              children: [
                ResponsiveFormField.full(
                  child: DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'مشتری *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    items: widget.store.customers
                        .map(
                          (customer) => DropdownMenuItem(
                            value: customer.id,
                            child: Text(
                              customer.company.isEmpty
                                  ? customer.name
                                  : customer.company,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'یک مشتری را انتخاب کنید.' : null,
                    onChanged: (value) => setState(() => _customerId = value),
                  ),
                ),
                ResponsiveFormField.full(
                  child: AutoInputDirection(
                    controller: _subject,
                    child: TextFormField(
                      controller: _subject,
                      inputFormatters: [textOnlyFormatter],
                      decoration: const InputDecoration(
                        labelText: 'موضوع تماس *',
                        prefixIcon: Icon(Icons.subject_rounded),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'موضوع تماس الزامی است.'
                          : null,
                    ),
                  ),
                ),
                ResponsiveFormField(
                  child: _dropdown('نوع تماس', _type, const [
                    'تلفنی',
                    'جلسه',
                    'استعلام',
                    'پیام',
                    'ایمیل',
                  ], (value) => _type = value),
                ),
                ResponsiveFormField(
                  child: _dropdown('جهت تماس', _direction, const [
                    'خروجی',
                    'ورودی',
                  ], (value) => _direction = value),
                ),
                ResponsiveFormField(
                  child: _dropdown('نتیجه تماس', _status, const [
                    'موفق',
                    'پیگیری',
                    'ناموفق',
                  ], (value) => _status = value),
                ),
                ResponsiveFormField(
                  child: _numberField(_duration, 'مدت (دقیقه)'),
                ),
                ResponsiveFormField(
                  child: _numberField(
                    _amount,
                    'مبلغ پایه / احتمالی (ریال)',
                    required: true,
                    rial: true,
                  ),
                ),
                ResponsiveFormField(
                  child: _dropdown('نوع معامله', _tradeType, const [
                    'فروش',
                    'خرید',
                    'بدون معامله',
                  ], (value) => _tradeType = value),
                ),
                ResponsiveFormField(
                  child: DropdownButtonFormField<String>(
                    initialValue: _productName.isEmpty ? null : _productName,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'کالا / خدمت',
                      suffixIcon: IconButton(
                        tooltip: 'افزودن در کالا و موجودی',
                        onPressed: widget.onOpenProducts == null
                            ? null
                            : () {
                                Navigator.pop(context, false);
                                widget.onOpenProducts!.call();
                              },
                        icon: const Icon(Icons.add_box_outlined),
                      ),
                    ),
                    items:
                        {
                              ...widget.store.products
                                  .where((item) => item.isActive)
                                  .map((item) => item.name),
                              if (_productName.isNotEmpty) _productName,
                            }
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() {
                      _productName = value ?? '';
                      final matches = widget.store.products
                          .where((item) => item.name == value)
                          .toList();
                      if (matches.isNotEmpty) {
                        _unitPrice.text = formatPersianInteger(
                          matches.first.unitPrice,
                          grouping: true,
                        );
                      }
                    }),
                  ),
                ),
                ResponsiveFormField(
                  child: _numberField(_quantity, 'تعداد یا تناژ'),
                ),
                ResponsiveFormField(
                  child: _numberField(_unitPrice, 'فی (ریال)', rial: true),
                ),
                ResponsiveFormField(
                  child: _numberField(_discount, 'تخفیف (ریالی)', rial: true),
                ),
                ResponsiveFormField(
                  child: _numberField(_taxPercent, 'ارزش افزوده (درصد)'),
                ),
                ResponsiveFormField.full(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 22,
                      runSpacing: 8,
                      children: [
                        Text('مبلغ پایه: ${compactMoney(_calculatedSubtotal)}'),
                        Text('خالص: ${compactMoney(_netAmount)}'),
                        Text('ارزش افزوده: ${compactMoney(_taxAmount)}'),
                        Text(
                          'جمع کل: ${compactMoney(_totalAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
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
                        labelText: 'شرح تماس و اقدام بعدی',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ),
                ResponsiveFormField.full(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _addFollowUp,
                    title: const Text('ایجاد پیگیری'),
                    subtitle: Text(
                      _nextFollowUp == null
                          ? 'بدون تاریخ'
                          : 'تاریخ پیگیری: ${compactDate(_nextFollowUp!)}',
                    ),
                    onChanged: (value) => setState(() {
                      _addFollowUp = value;
                      _nextFollowUp ??= DateTime.now().add(
                        const Duration(days: 1),
                      );
                    }),
                  ),
                ),
                if (_addFollowUp)
                  ResponsiveFormField.full(
                    child: OutlinedButton.icon(
                      onPressed: _pickFollowUpDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _nextFollowUp == null
                            ? 'انتخاب تاریخ پیگیری'
                            : 'تاریخ پیگیری: ${compactDate(_nextFollowUp!)}',
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
          label: Text(widget.call == null ? 'ثبت تماس' : 'ذخیره تغییرات'),
        ),
      ],
    );
  }

  Widget _dropdown(
    String label,
    String selected,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => setState(() => onChanged(value ?? selected)),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool rial = false,
  }) {
    return AutoInputDirection(
      controller: controller,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: rial
            ? const [persianRialFormatter]
            : const [persianNumberFormatter],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'مبلغ را وارد کنید.'
                  : null
            : null,
      ),
    );
  }
}
