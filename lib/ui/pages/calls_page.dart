import 'package:flutter/material.dart';

import '../../core/crm_store.dart';
import '../../core/models.dart';
import '../../core/report_service.dart';
import '../widgets/common.dart';

class CallsPage extends StatefulWidget {
  const CallsPage({super.key, required this.store, this.initialStatus});

  final CrmStore store;
  final String? initialStatus;

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  final _search = TextEditingController();
  int _sortColumn = 7;
  bool _sortAscending = false;
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _CallEditorDialog(
        store: widget.store,
        call: call,
        initialCustomerId: customerId,
      ),
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

  void _sort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
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

  Future<void> _printCalls({bool todayOnly = false}) {
    final today = DateTime.now();
    final calls = _filteredCalls().where(
      (item) =>
          !todayOnly ||
          (item.callAt.year == today.year &&
              item.callAt.month == today.month &&
              item.callAt.day == today.day),
    );
    return CrmReportService.printTable(
      title: todayOnly ? 'گزارش روزانه مدیر' : 'گزارش تماس‌ها و جلسات',
      subtitle: todayOnly ? 'تاریخ: ${compactDate(today)}' : '',
      headers: const [
        'مشتری',
        'موضوع',
        'نوع',
        'نتیجه',
        'خرید/فروش',
        'تاریخ',
        'مبلغ',
      ],
      rows: calls
          .map(
            (item) => <Object?>[
              item.customerName,
              item.subject,
              item.type,
              item.status,
              item.tradeType,
              compactDate(item.callAt),
              formatPersianInteger(item.amount),
            ],
          )
          .toList(),
    );
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
    final values = <Comparable<Object?> Function(CrmCall)>[
      (item) => item.customerName,
      (item) => item.subject,
      (item) => item.type,
      (item) => item.status,
      (item) => item.tradeType,
      (item) => item.productName,
      (item) => item.quantity,
      (item) => item.callAt,
      (item) => item.durationMinutes,
      (item) => item.amount,
    ];
    rows.sort((left, right) {
      final result = values[_sortColumn](
        left,
      ).compareTo(values[_sortColumn](right));
      return _sortAscending ? result : -result;
    });
    final failed = store.calls.where((call) => call.status == 'ناموفق').length;
    return ListView(
      children: [
        CrmPageHeader(
          title: 'مدیریت تماس‌ها',
          subtitle: 'تماس‌ها، نتیجه، مبلغ احتمالی و پیگیری بعدی را ثبت کنید.',
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printCalls(todayOnly: true),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('کارتابل روزانه مدیر'),
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
                const ['خیلی بالا', 'بالا', 'متوسط', 'پایین'],
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
              : CrmTableScroll(
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    sortColumnIndex: _sortColumn,
                    sortAscending: _sortAscending,
                    columns: [
                      DataColumn(
                        label: const Text('مشتری'),
                        onSort: (_, _) => _sort(0),
                      ),
                      DataColumn(
                        label: const Text('موضوع تماس'),
                        onSort: (_, _) => _sort(1),
                      ),
                      DataColumn(
                        label: const Text('نوع'),
                        onSort: (_, _) => _sort(2),
                      ),
                      DataColumn(
                        label: const Text('نتیجه'),
                        onSort: (_, _) => _sort(3),
                      ),
                      DataColumn(
                        label: const Text('خرید / فروش'),
                        onSort: (_, _) => _sort(4),
                      ),
                      DataColumn(
                        label: const Text('کالا'),
                        onSort: (_, _) => _sort(5),
                      ),
                      DataColumn(
                        label: const Text('تعداد / تناژ'),
                        numeric: true,
                        onSort: (_, _) => _sort(6),
                      ),
                      DataColumn(
                        label: const Text('تاریخ'),
                        onSort: (_, _) => _sort(7),
                      ),
                      DataColumn(
                        label: const Text('مدت'),
                        numeric: true,
                        onSort: (_, _) => _sort(8),
                      ),
                      DataColumn(
                        label: const Text('مبلغ احتمالی (ریال)'),
                        numeric: true,
                        onSort: (_, _) => _sort(9),
                      ),
                      const DataColumn(label: Text('عملیات')),
                    ],
                    rows: rows
                        .map(
                          (call) => DataRow(
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 175,
                                  child: Text(
                                    call.customerName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    call.subject,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(call.type)),
                              DataCell(StatusPill(label: call.status)),
                              DataCell(
                                Text(
                                  call.tradeType.isEmpty ? '—' : call.tradeType,
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    call.productName.isEmpty
                                        ? '—'
                                        : call.productName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  call.quantity == 0
                                      ? '—'
                                      : formatPersianInteger(
                                          call.quantity,
                                          grouping: false,
                                        ),
                                ),
                              ),
                              DataCell(Text(compactDate(call.callAt))),
                              DataCell(
                                Text(
                                  '${formatPersianInteger(call.durationMinutes)} دقیقه',
                                ),
                              ),
                              DataCell(Text(compactMoney(call.amount))),
                              DataCell(
                                RecordActions(
                                  onEdit: () => _openEditor(call),
                                  onDelete: () => _delete(call),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
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
  });

  final CrmStore store;
  final CrmCall? call;
  final String? initialCustomerId;

  @override
  State<_CallEditorDialog> createState() => _CallEditorDialogState();
}

class _CallEditorDialogState extends State<_CallEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _notes = TextEditingController();
  final _duration = TextEditingController(text: '۵');
  final _amount = TextEditingController(text: '۰');
  final _product = TextEditingController();
  final _quantity = TextEditingController(text: '۰');
  final _unitPrice = TextEditingController(text: '۰');
  String? _customerId;
  String _type = 'تلفنی';
  String _direction = 'خروجی';
  String _status = 'موفق';
  String _tradeType = 'فروش';
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
    _product.text = call.productName;
    _quantity.text = formatPersianInteger(call.quantity);
    _unitPrice.text = formatPersianInteger(call.unitPrice, grouping: true);
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
    _product.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final customer = widget.store.customers.firstWhere(
      (item) => item.id == _customerId,
    );
    setState(() => _saving = true);
    await widget.store.saveCall(
      customer: customer,
      subject: _subject.text,
      type: _type,
      direction: _direction,
      status: _status,
      notes: _notes.text,
      durationMinutes: parsePersianInt(_duration.text),
      amount: parsePersianInt(_amount.text),
      tradeType: _tradeType,
      productName: _product.text,
      quantity: parsePersianInt(_quantity.text),
      unitPrice: parsePersianInt(_unitPrice.text),
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
                    'مبلغ احتمالی (ریال)',
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
                  child: AutoInputDirection(
                    controller: _product,
                    child: TextFormField(
                      controller: _product,
                      inputFormatters: [textOnlyFormatter],
                      decoration: const InputDecoration(
                        labelText: 'کالا / خدمت',
                      ),
                    ),
                  ),
                ),
                ResponsiveFormField(
                  child: _numberField(_quantity, 'تعداد یا تناژ'),
                ),
                ResponsiveFormField(
                  child: _numberField(_unitPrice, 'فی (ریال)', rial: true),
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
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'مبلغ را وارد کنید.'
                  : null
            : null,
      ),
    );
  }
}
